import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:id3/id3.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/eleccion_letra.dart';
import '../utils/lyrics_parsing.dart';

export '../utils/lyrics_parsing.dart' show LineaLetra;

class Lyrics {
  final List<LineaLetra>? lineas;
  final String? textoPlano;

  const Lyrics({this.lineas, this.textoPlano});

  bool get estaSincronizada => lineas != null && lineas!.isNotEmpty;
  bool get hayAlgo =>
      estaSincronizada || (textoPlano != null && textoPlano!.trim().isNotEmpty);

  static const Lyrics vacia = Lyrics();
}

class LyricsService {
  // Constructor privado: acepta un http.Client opcional para poder
  // testear esta clase sin red real (ver LyricsService.testable más
  // abajo). Si no se pasa ninguno (el caso normal de la app), se crea
  // un http.Client de verdad. Mismo patrón que JamendoService.
  LyricsService._({http.Client? client}) : _client = client ?? http.Client();

  /// Instancia real que usa el resto de la app (`LyricsService.instance`).
  static final LyricsService instance = LyricsService._();

  /// SOLO PARA TESTS: permite inyectar un http.Client falso/mockeado
  /// para testear `getLyrics` sin depender de la red. No usar esto en
  /// código de la app -- ahí siempre se usa `.instance`.
  factory LyricsService.testable(http.Client client) =>
      LyricsService._(client: client);

  final http.Client _client;

  final Map<String, Lyrics> _cache = {};

  String _clave(String title, String artist) =>
      '${title.toLowerCase()}|${artist.toLowerCase()}';

  /// La `v2` no es decorativa: sube de versión a propósito para que se
  /// descarte TODO lo que se guardó con la regla vieja.
  ///
  /// Hasta la vuelta 42, la app tomaba el primer resultado de lrclib a
  /// ciegas y guardaba en disco letras que eran de otra canción (el
  /// caso comprobado: "Refuse Amen", en inglés, para "Amén"). Como lo
  /// guardado se lee ANTES de buscar nada, esas letras equivocadas
  /// seguirían mostrándose para siempre aunque la regla nueva esté
  /// bien. Cambiando el nombre, se vuelven a buscar una sola vez.
  String _prefKey(String clave) => 'lyrics_cache_v2_$clave';
  static const String _prefijoViejo = 'lyrics_cache_v1_';
  // Por instancia y no `static`: en la app hay una sola (`instance`),
  // asi que se limpia una vez igual, pero deja de depender del orden en
  // que corren los tests.
  bool _yaSeLimpioLoViejo = false;

  /// Borra de una sola vez las letras guardadas con la regla vieja.
  /// Solo es para no dejar basura ocupando lugar: con el nombre nuevo
  /// ya no se leen igual.
  Future<void> _limpiarLoGuardadoConLaReglaVieja(
      SharedPreferences prefs) async {
    if (_yaSeLimpioLoViejo) return;
    _yaSeLimpioLoViejo = true;
    try {
      for (final clave in prefs.getKeys().toList()) {
        if (clave.startsWith(_prefijoViejo)) await prefs.remove(clave);
      }
    } catch (_) {}
  }

  /// [duracion] es cuánto dura de verdad la canción o el video que está
  /// sonando. Sirve para descartar resultados que son otra canción con
  /// el mismo nombre -- ver `utils/eleccion_letra.dart`. Es opcional:
  /// si no se sabe, la búsqueda funciona como antes.
  Future<Lyrics> getLyrics({
    required String title,
    required String artist,
    required String urlCancion,
    Duration? duracion,
  }) async {
    final clave = _clave(title, artist);
    if (_cache.containsKey(clave)) return _cache[clave]!;

    try {
      final prefs = await SharedPreferences.getInstance();
      await _limpiarLoGuardadoConLaReglaVieja(prefs);
      final guardado = prefs.getString(_prefKey(clave));
      if (guardado != null) {
        final letra = _deserializar(guardado);
        _recordar(clave, letra);
        return letra;
      }
    } catch (_) {}

    final tituloLimpio = limpiarTituloParaBuscarLetra(title);

    // Intento 1: título + artista tal cual vienen.
    Lyrics? letra =
        await _buscarEnLrclib(tituloLimpio, artist, duracion: duracion);

    // Intento 2: muchos resultados de "Búsqueda Online" (YouTube) traen
    // el nombre del CANAL como "artista" (ej. "Dj Montro Live" subiendo
    // un compilado de salsa), no el artista real -- eso hace fallar la
    // búsqueda por más que la canción sí tenga letra en la base de
    // datos. Es muy común que el título del video en realidad sea
    // "Artista Real - Nombre de la Canción". Si el intento 1 no
    // encontró nada y el título tiene ese patrón, lo separamos y
    // probamos con el artista real que salió del propio título.
    if ((letra == null || !letra.hayAlgo) && tituloLimpio.contains(' - ')) {
      final partes = tituloLimpio.split(' - ');
      final artistaDelTitulo = partes.first.trim();
      final tituloSinArtista = partes.sublist(1).join(' - ').trim();
      if (artistaDelTitulo.isNotEmpty && tituloSinArtista.isNotEmpty) {
        letra = await _buscarEnLrclib(tituloSinArtista, artistaDelTitulo,
            duracion: duracion);
      }
    }

    // Intento 3: búsqueda amplia solo por título, sin artista -- por si
    // el artista (venga de donde venga) no coincide con como está
    // catalogada la canción en lrclib, pero el título sí es único
    // como para encontrarla igual.
    if (letra == null || !letra.hayAlgo) {
      letra = await _buscarEnLrclib(tituloLimpio, null, duracion: duracion);
    }

    // Intento 4: tags ID3 embebidas en el propio archivo de audio (si
    // la fuente las trae, esto es 100% confiable porque es texto que
    // vino con la canción, no una búsqueda por nombre).
    letra ??= await _buscarEnId3(urlCancion);

    // Intento 5 (último recurso): lyrics.ovh, una API gratuita más
    // vieja y con menos cobertura que lrclib, pero que a veces tiene
    // canciones que lrclib no tiene (y viceversa) -- vale la pena
    // probarla antes de rendirse del todo.
    letra ??= await _buscarEnLyricsOvh(tituloLimpio, artist);

    final resultado = letra ?? Lyrics.vacia;
    _recordar(clave, resultado);
    // Solo se guarda en disco lo que SI se encontro. Antes tambien se
    // guardaba el "no hay letra", asi que una sola consulta hecha sin
    // internet dejaba esa cancion marcada como "sin letra" para
    // siempre, incluso con la conexion ya funcionando. El "no hay"
    // sigue viviendo en memoria, que alcanza para no repetir la
    // busqueda cinco veces dentro de la misma sesion.
    if (resultado.hayAlgo) _guardar(clave, resultado);
    return resultado;
  }

  // Tope de letras en memoria, por el mismo motivo que las caratulas
  // en `id3_cover_service.dart`: una biblioteca grande escuchada de
  // punta a punta llenaba este mapa sin que nada lo vaciara nunca.
  static const int _maxLetrasEnMemoria = 60;
  final List<String> _ordenCache = [];

  void _recordar(String clave, Lyrics letra) {
    if (!_cache.containsKey(clave)) _ordenCache.add(clave);
    _cache[clave] = letra;
    while (_ordenCache.length > _maxLetrasEnMemoria) {
      _cache.remove(_ordenCache.removeAt(0));
    }
  }

  Future<Lyrics?> _buscarEnLyricsOvh(String title, String artist) async {
    if (artist.trim().isEmpty || title.trim().isEmpty) return null;
    try {
      final url = Uri.parse(
        'https://api.lyrics.ovh/v1/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}',
      );
      final response =
          await _client.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final texto = decoded['lyrics'] as String?;
      if (texto == null || texto.trim().isEmpty) return null;
      return Lyrics(textoPlano: texto.trim());
    } catch (_) {
      return null;
    }
  }

  Future<Lyrics?> _buscarEnLrclib(
    String title,
    String? artist, {
    Duration? duracion,
  }) async {
    try {
      final query = StringBuffer('track_name=${Uri.encodeComponent(title)}');
      if (artist != null && artist.trim().isNotEmpty) {
        query.write('&artist_name=${Uri.encodeComponent(artist)}');
      }
      final url = Uri.parse('https://lrclib.net/api/search?$query');
      final response =
          await _client.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final resultados = jsonDecode(response.body) as List;
      // Antes se tomaba `resultados.first` a ciegas. Ver la explicación
      // en `utils/eleccion_letra.dart`: así la app mostraba la letra de
      // una canción completamente distinta con total seguridad.
      final primero = elegirLetraDeLrclib(
        resultados,
        duracion: duracion,
        artistaBuscado: artist,
      );
      if (primero == null) return null;

      final synced = primero['syncedLyrics'] as String?;
      final plano = primero['plainLyrics'] as String?;

      if (synced != null && synced.trim().isNotEmpty) {
        final lineas = parsearLrc(synced);
        if (lineas.isNotEmpty) return Lyrics(lineas: lineas, textoPlano: plano);
      }
      if (plano != null && plano.trim().isNotEmpty) {
        return Lyrics(textoPlano: plano);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Lyrics?> _buscarEnId3(String url) async {
    if (url.isEmpty) return null;
    try {
      List<int> bytes;
      final esArchivoLocal =
          !url.startsWith('http://') && !url.startsWith('https://');

      if (esArchivoLocal) {
        final archivo = File(url);
        if (!await archivo.exists()) return null;
        bytes = await archivo.readAsBytes();
      } else {
        final response = await _client.get(Uri.parse(url), headers: {
          'Range': 'bytes=0-524287'
        }).timeout(const Duration(seconds: 8));
        if (response.statusCode != 200 && response.statusCode != 206) {
          return null;
        }
        bytes = response.bodyBytes;
      }

      final mp3 = MP3Instance(bytes);
      if (!mp3.parseTagsSync()) return null;
      final tags = mp3.getMetaTags();
      final uslt = tags?['USLT'];

      String? texto;
      if (uslt is String) {
        texto = uslt;
      } else if (uslt is Map) {
        texto = (uslt['text'] ?? uslt['description']) as String?;
      }

      if (texto == null || texto.trim().isEmpty) return null;
      return Lyrics(textoPlano: texto);
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardar(String clave, Lyrics letra) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey(clave), _serializar(letra));
    } catch (_) {}
  }

  String _serializar(Lyrics letra) {
    return jsonEncode({
      'plano': letra.textoPlano,
      'lineas': letra.lineas
          ?.map((l) => {'ms': l.tiempo.inMilliseconds, 'texto': l.texto})
          .toList(),
    });
  }

  Lyrics _deserializar(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final lineasRaw = decoded['lineas'] as List?;

      final lineas = lineasRaw?.map((e) {
        // Soporte robusto tanto para 'ms' como si existiera un registro previo con 'segundos'
        final ms = e['ms'] ?? ((e['segundos'] ?? 0) * 1000);
        return LineaLetra(
          Duration(milliseconds: ms is int ? ms : (ms as double).toInt()),
          e['texto'] as String,
        );
      }).toList();

      return Lyrics(
        textoPlano: decoded['plano'] as String?,
        lineas: (lineas != null && lineas.isNotEmpty) ? lineas : null,
      );
    } catch (_) {
      return Lyrics.vacia;
    }
  }
}
