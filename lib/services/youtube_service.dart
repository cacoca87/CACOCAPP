import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/app_logger.dart';

/// Resultado de búsqueda ya adaptado a lo que necesita la UI de
/// `dual_search_screen.dart`. Se mantiene esta forma (en vez de exponer
/// directamente el `Video` de youtube_explode_dart) para que el resto
/// de la app no dependa de los tipos internos del paquete.
class YoutubeVideoResult {
  final String videoId;
  final String title;
  final String author;
  final String lengthSeconds; // formateado "m:ss", para mostrar en la UI
  final int lengthInSeconds; // crudo, para ordenar/filtrar
  final String viewCount; // formateado "1234 vistas"
  final String thumbnailUrl;

  YoutubeVideoResult({
    required this.videoId,
    required this.title,
    required this.author,
    required this.lengthSeconds,
    required this.lengthInSeconds,
    required this.viewCount,
    required this.thumbnailUrl,
  });

  factory YoutubeVideoResult.fromVideo(Video video) {
    final segundos = video.duration?.inSeconds ?? 0;
    final minutos = segundos ~/ 60;
    final segundosRestantes = segundos % 60;
    return YoutubeVideoResult(
      videoId: video.id.value,
      title: video.title,
      author: video.author,
      lengthSeconds: '$minutos:${segundosRestantes.toString().padLeft(2, '0')}',
      lengthInSeconds: segundos,
      viewCount: '${video.engagement.viewCount} vistas',
      thumbnailUrl: video.thumbnails.highResUrl,
    );
  }
}

/// Un candidato de audio ya resuelto: URL directa + su extensión real.
class AudioCandidato {
  final String url;
  final String extension;
  final String origen; // solo para logs/depuración: qué método lo resolvió
  AudioCandidato(this.url, this.extension, this.origen);
}

/// Busca videos en YouTube (vía `youtube_explode_dart`) y resuelve el
/// audio probando, EN ORDEN, tres métodos independientes hasta que
/// alguno funcione:
///
///   1. Resolución directa en el dispositivo (`youtube_explode_dart`).
///      La más rápida, no depende de ningún servidor externo -- pero
///      es la más castigada por los bloqueos de YouTube.
///   2. Tu servidor proxy propio (`proxy-audio-server/`, desplegado en
///      Render). Corre en un datacenter, y resuelve el audio ahí en
///      vez de en el celular.
///   3. Una instancia pública de Invidious, mantenida por voluntarios
///      externos, como último recurso.
///
/// Ninguno de los tres es infalible por separado -- YouTube pelea
/// activamente contra los tres por igual. La idea de encadenarlos no
/// es "arreglar" el problema de fondo (no tiene arreglo definitivo),
/// sino bajar la chance de que TODOS fallen al mismo tiempo: son tres
/// implementaciones independientes, mantenidas por equipos distintos,
/// así que no se rompen necesariamente juntas.
class YoutubeService {
  static final YoutubeService instance = YoutubeService._internal();
  YoutubeService._internal();

  final YoutubeExplode _yt = YoutubeExplode();

  /// URL pública de tu servidor proxy en Render, SIN la barra final.
  /// Ejemplo real: 'https://cacocapp-audio-proxy.onrender.com'
  static const String _proxyBaseUrl = 'https://TU-SERVIDOR.onrender.com';

  Future<List<YoutubeVideoResult>> buscarVideos(String query) async {
    try {
      final resultados = await _yt.search.search(query);
      // Antes se filtraban los videos de más de 12 minutos y se
      // ordenaba de más corto a más largo -- tenía sentido cuando la
      // app extraía y bufferizaba el audio ella misma (los mixes/shows
      // largos agotaban el buffer). Desde que la reproducción pasa por
      // el reproductor oficial embebido de YouTube (que maneja su
      // propio buffer, igual que la app real), ese límite ya no
      // protege de nada -- solo escondía resultados válidos (un
      // recital, un álbum completo en un video) sin motivo.
      return resultados.map(YoutubeVideoResult.fromVideo).toList();
    } catch (_) {
      return [];
    }
  }

  /// Prueba los 3 métodos EN ORDEN y devuelve los candidatos del
  /// primero que consiga alguno. Se corta apenas uno responde (no se
  /// prueban los 3 siempre) para no pagar la latencia de los métodos
  /// más lentos cuando el rápido ya funcionó.
  Future<List<AudioCandidato>> obtenerCandidatosDeAudio(String videoId) async {
    final directos = await _candidatosDirectos(videoId);
    if (directos.isNotEmpty) return directos;

    AppLogger.w('Resolución directa falló para $videoId, probando el proxy propio...');
    final delProxy = await _candidatosDelProxy(videoId);
    if (delProxy.isNotEmpty) return delProxy;

    AppLogger.w('Proxy propio falló para $videoId, probando Invidious como último recurso...');
    final deInvidious = await _candidatosDeInvidious(videoId);
    return deInvidious;
  }

  /// Devuelve la URL directa del audio preferido para el video, lista
  /// para pasarle a just_audio o para descargar con un `http.get` normal.
  Future<String?> obtenerUrlAudioPuro(String videoId) async {
    final candidatos = await obtenerCandidatosDeAudio(videoId);
    return candidatos.isEmpty ? null : candidatos.first.url;
  }

  // ---------------------------------------------------------------------
  // Método 1: resolución directa en el dispositivo (youtube_explode_dart)
  // ---------------------------------------------------------------------

  Future<List<AudioCandidato>> _candidatosDirectos(String videoId) async {
    final manifest = await _getManifestConRespaldoDeClientes(videoId);
    if (manifest == null || manifest.audioOnly.isEmpty) return [];

    // Se prefiere el de MENOR bitrate por encima de un piso de calidad
    // razonable (64kbps): pesa menos y bufferea más rápido, y el
    // issue #332 del propio repositorio reporta que el de mayor
    // bitrate es el que más 403 dispara.
    final audios = manifest.audioOnly.toList()
      ..sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
    final conBuenaCalidad = audios.where((a) => a.bitrate.bitsPerSecond >= 64000).toList();
    final ordenPreferido = conBuenaCalidad.isNotEmpty ? conBuenaCalidad : audios;

    return ordenPreferido
        .map((a) => AudioCandidato(a.url.toString(), a.container.name, 'directo'))
        .toList();
  }

  Future<StreamManifest?> _getManifestConRespaldoDeClientes(String videoId) async {
    final combinacionesDeClientes = <List<YoutubeApiClient>?>[
      [YoutubeApiClient.ios, YoutubeApiClient.androidVr],
      [YoutubeApiClient.android],
      [YoutubeApiClient.safari],
      null, // resolución por defecto del paquete, último recurso
    ];

    for (final clientes in combinacionesDeClientes) {
      try {
        final manifest = clientes == null
            ? await _yt.videos.streams.getManifest(videoId)
            : await _yt.videos.streams.getManifest(videoId, ytClients: clientes);
        if (manifest.audioOnly.isNotEmpty) return manifest;
      } catch (_) {
        // Se prueba con el siguiente cliente de la lista.
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Método 2: servidor proxy propio (Render)
  // ---------------------------------------------------------------------

  Future<List<AudioCandidato>> _candidatosDelProxy(String videoId) async {
    if (_proxyBaseUrl.contains('TU-SERVIDOR')) {
      // Todavía no configuraste tu URL real de Render -- se salta este
      // método en silencio (no tiene sentido intentar una URL que
      // sabemos que no existe) y se sigue con Invidious.
      return [];
    }
    // El proxy resuelve todo del lado del servidor -- acá solo se arma
    // la URL. El contenedor típico que entrega youtubei.js para audio
    // "best" es webm (opus).
    return [AudioCandidato('$_proxyBaseUrl/stream?id=$videoId', 'webm', 'proxy propio')];
  }

  // ---------------------------------------------------------------------
  // Método 3: instancias públicas de Invidious (último recurso)
  // ---------------------------------------------------------------------

  static const _prefsListaKey = 'invidious_instancias_v1';
  static const _prefsFechaKey = 'invidious_instancias_fecha_v1';
  static const _duracionCacheInstancias = Duration(hours: 12);
  static const List<String> _instanciasRespaldoFijas = [
    'https://vid.puffyan.us',
    'https://invidious.privacyredirect.com',
    'https://invidious.nerdvpn.de',
    'https://inv.nadeko.net',
  ];

  List<String>? _cacheInstanciasEnMemoria;
  DateTime? _fechaCacheInstancias;

  Future<List<AudioCandidato>> _candidatosDeInvidious(String videoId) async {
    for (final baseUrl in await _obtenerInstanciasInvidious()) {
      try {
        final url = Uri.parse('$baseUrl/api/v1/videos/$videoId');
        final response = await http.get(url).timeout(const Duration(seconds: 6));
        if (response.statusCode != 200) continue;

        final data = json.decode(response.body);
        final adaptiveFormats = data['adaptiveFormats'] as List<dynamic>?;
        if (adaptiveFormats == null) continue;

        final formatosAudio = adaptiveFormats
            .where((f) => (f['type']?.toString() ?? '').contains('audio'))
            .toList();
        if (formatosAudio.isEmpty) continue;

        int bitrateDe(dynamic f) => int.tryParse(f['bitrate']?.toString() ?? '') ?? 999999999;
        formatosAudio.sort((a, b) => bitrateDe(a).compareTo(bitrateDe(b)));
        final conBuenaCalidad = formatosAudio.where((f) => bitrateDe(f) >= 64000).toList();
        final elegido = (conBuenaCalidad.isNotEmpty ? conBuenaCalidad : formatosAudio).first;

        if (elegido['url'] != null) {
          return [AudioCandidato(elegido['url'], 'webm', 'Invidious ($baseUrl)')];
        }
      } catch (_) {
        // Se prueba la siguiente instancia.
      }
    }
    return [];
  }

  /// Lista de instancias a probar: primero las que salen como activas
  /// AHORA MISMO en el directorio público de Invidious
  /// (api.invidious.io), cacheadas 12hs, y al final las de respaldo
  /// fijas por si ninguna dinámica responde.
  Future<List<String>> _obtenerInstanciasInvidious() async {
    if (_cacheInstanciasEnMemoria != null &&
        _fechaCacheInstancias != null &&
        DateTime.now().difference(_fechaCacheInstancias!) < _duracionCacheInstancias) {
      return _cacheInstanciasEnMemoria!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final fechaGuardadaMs = prefs.getInt(_prefsFechaKey);
      final listaGuardada = prefs.getStringList(_prefsListaKey);
      if (fechaGuardadaMs != null && listaGuardada != null && listaGuardada.isNotEmpty) {
        final fecha = DateTime.fromMillisecondsSinceEpoch(fechaGuardadaMs);
        if (DateTime.now().difference(fecha) < _duracionCacheInstancias) {
          _cacheInstanciasEnMemoria = listaGuardada;
          _fechaCacheInstancias = fecha;
          return listaGuardada;
        }
      }
    } catch (_) {}

    final descubiertas = await _descubrirInstanciasInvidiousActivas();
    final combinadas = <String>[
      ...descubiertas,
      for (final fija in _instanciasRespaldoFijas)
        if (!descubiertas.contains(fija)) fija,
    ];

    _cacheInstanciasEnMemoria = combinadas;
    _fechaCacheInstancias = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsListaKey, combinadas);
      await prefs.setInt(_prefsFechaKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}

    return combinadas;
  }

  Future<List<String>> _descubrirInstanciasInvidiousActivas() async {
    try {
      final url = Uri.parse('https://api.invidious.io/instances.json?sort_by=type,users');
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as List<dynamic>;
      final instancias = <String>[];
      for (final entry in data) {
        if (entry is! List || entry.length < 2) continue;
        final detalle = entry[1] as Map<String, dynamic>?;
        if (detalle == null) continue;
        if (detalle['type'] != 'https') continue;
        final uri = detalle['uri'] as String?;
        if (uri == null || uri.isEmpty) continue;
        instancias.add(uri.endsWith('/') ? uri.substring(0, uri.length - 1) : uri);
        if (instancias.length >= 8) break;
      }
      return instancias;
    } catch (e) {
      AppLogger.w('No se pudo descubrir instancias de Invidious: $e');
      return [];
    }
  }
}
