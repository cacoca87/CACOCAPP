import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:id3/id3.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LineaLetra {
  final Duration tiempo;
  final String texto;
  const LineaLetra(this.tiempo, this.texto);
}

class Lyrics {
  final List<LineaLetra>? lineas;
  final String? textoPlano;

  const Lyrics({this.lineas, this.textoPlano});

  bool get estaSincronizada => lineas != null && lineas!.isNotEmpty;
  bool get hayAlgo => estaSincronizada || (textoPlano != null && textoPlano!.trim().isNotEmpty);

  static const Lyrics vacia = Lyrics();
}

class LyricsService {
  LyricsService._();
  static final LyricsService instance = LyricsService._();

  final Map<String, Lyrics> _cache = {};

  String _clave(String title, String artist) => '${title.toLowerCase()}|${artist.toLowerCase()}';
  String _prefKey(String clave) => 'lyrics_cache_v1_$clave';

  Future<Lyrics> getLyrics({
    required String title,
    required String artist,
    required String urlCancion,
  }) async {
    final clave = _clave(title, artist);
    if (_cache.containsKey(clave)) return _cache[clave]!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(_prefKey(clave));
      if (guardado != null) {
        final letra = _deserializar(guardado);
        _cache[clave] = letra;
        return letra;
      }
    } catch (_) {}

    final tituloLimpio = _limpiarTitulo(title);

    // Intento 1: título + artista tal cual vienen.
    Lyrics? letra = await _buscarEnLrclib(tituloLimpio, artist);

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
        letra = await _buscarEnLrclib(tituloSinArtista, artistaDelTitulo);
      }
    }

    // Intento 3: búsqueda amplia solo por título, sin artista -- por si
    // el artista (venga de donde venga) no coincide con como está
    // catalogada la canción en lrclib, pero el título sí es único
    // como para encontrarla igual.
    if (letra == null || !letra.hayAlgo) {
      letra = await _buscarEnLrclib(tituloLimpio, null);
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
    _cache[clave] = resultado;
    _guardar(clave, resultado);
    return resultado;
  }

  /// Saca ruido típico de títulos de YouTube ("(Official Video)",
  /// "[Lyrics]", "(Audio)", "HD", etc.) que hace fallar la búsqueda
  /// exacta en lrclib. No toca el título real de la canción en la UI,
  /// solo se usa para buscar la letra.
  String _limpiarTitulo(String titulo) {
    var limpio = titulo;
    final patronesRuido = [
      RegExp(r'\(\s*official\s*(music\s*)?video\s*\)', caseSensitive: false),
      RegExp(r'\(\s*official\s*audio\s*\)', caseSensitive: false),
      RegExp(r'\(\s*official\s*lyric[s]?\s*video\s*\)', caseSensitive: false),
      RegExp(r'\(\s*video\s*oficial\s*\)', caseSensitive: false),
      RegExp(r'\(\s*audio\s*oficial\s*\)', caseSensitive: false),
      RegExp(r'\[\s*official\s*video\s*\]', caseSensitive: false),
      RegExp(r'\(\s*lyrics?\s*\)', caseSensitive: false),
      RegExp(r'\[\s*lyrics?\s*\]', caseSensitive: false),
      RegExp(r'\(\s*audio\s*\)', caseSensitive: false),
      RegExp(r'\(\s*visualizer\s*\)', caseSensitive: false),
      RegExp(r'\b(hd|4k|full hd|hq)\b', caseSensitive: false),
    ];
    for (final patron in patronesRuido) {
      limpio = limpio.replaceAll(patron, '');
    }
    return limpio.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<Lyrics?> _buscarEnLyricsOvh(String title, String artist) async {
    if (artist.trim().isEmpty || title.trim().isEmpty) return null;
    try {
      final url = Uri.parse(
        'https://api.lyrics.ovh/v1/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final texto = decoded['lyrics'] as String?;
      if (texto == null || texto.trim().isEmpty) return null;
      return Lyrics(textoPlano: texto.trim());
    } catch (_) {
      return null;
    }
  }

  Future<Lyrics?> _buscarEnLrclib(String title, String? artist) async {
    try {
      final query = StringBuffer('track_name=${Uri.encodeComponent(title)}');
      if (artist != null && artist.trim().isNotEmpty) {
        query.write('&artist_name=${Uri.encodeComponent(artist)}');
      }
      final url = Uri.parse('https://lrclib.net/api/search?$query');
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final resultados = jsonDecode(response.body) as List;
      if (resultados.isEmpty) return null;

      final primero = resultados.first as Map<String, dynamic>;
      final synced = primero['syncedLyrics'] as String?;
      final plano = primero['plainLyrics'] as String?;

      if (synced != null && synced.trim().isNotEmpty) {
        final lineas = _parsearLrc(synced);
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
      final esArchivoLocal = !url.startsWith('http://') && !url.startsWith('https://');

      if (esArchivoLocal) {
        final archivo = File(url);
        if (!await archivo.exists()) return null;
        bytes = await archivo.readAsBytes();
      } else {
        final response = await http
            .get(Uri.parse(url), headers: {'Range': 'bytes=0-524287'})
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200 && response.statusCode != 206) return null;
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

  List<LineaLetra> _parsearLrc(String contenido) {
    final regex = RegExp(r'\[(\d{2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    final lineas = <LineaLetra>[];

    for (final linea in contenido.split('\n')) {
      final coincidencias = regex.allMatches(linea).toList();
      if (coincidencias.isEmpty) continue;

      final texto = linea.replaceAll(regex, '').trim();
      if (texto.isEmpty) continue;

      for (final m in coincidencias) {
        final minutos = int.parse(m.group(1)!);
        final segundosVal = int.parse(m.group(2)!);
        final fraccion = m.group(3);
        final milisegundos = fraccion == null
            ? 0
            : int.parse(fraccion.padRight(3, '0').substring(0, 3));
            
        // Se usa Duration correctamente sin pasar parámetros nombrados erróneos
        lineas.add(LineaLetra(
          Duration(minutes: minutos, seconds: segundosVal, milliseconds: milisegundos),
          texto,
        ));
      }
    }

    lineas.sort((a, b) => a.tiempo.compareTo(b.tiempo));
    return lineas;
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