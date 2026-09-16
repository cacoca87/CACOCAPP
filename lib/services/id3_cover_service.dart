import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:id3/id3.dart';
import 'package:path_provider/path_provider.dart';

/// Extrae metadata REAL incrustada en el propio MP3 (tags ID3v2):
/// carátula (frame APIC) y nombre de álbum (frame TALB) — tal como lo
/// hace un reproductor profesional, sin necesitar servidor propio ni
/// descargar el archivo completo.
///
/// Solo pedimos los primeros ~512KB vía HTTP Range, donde normalmente
/// viven los tags ID3v2 (van al inicio del archivo). R2/Cloudflare
/// soporta peticiones por rango igual que cualquier bucket S3.
///
/// La carátula y el álbum comparten el mismo parseo de tags — así que
/// si `SongCover` ya pidió la carátula de una canción, pedir después
/// su álbum es prácticamente gratis (no hay una segunda petición de
/// red, se reusa lo que ya se parseó en memoria).
///
/// Todo se guarda también en disco (carpeta de caché de la app): antes,
/// cerrar la app por completo perdía todo el trabajo hecho y tocaba
/// re-descargar/re-leer el ID3 de cada canción otra vez. Ahora la
/// primera vez cuesta red; las siguientes son instantáneas.
class Id3CoverService {
  Id3CoverService._();
  static final Id3CoverService instance = Id3CoverService._();

  final Map<String, Uint8List?> _cacheCaratula = {};
  final Map<String, String?> _cacheAlbum = {};
  final Map<String, String?> _cacheArtista = {};

  // Las carátulas también quedan guardadas en disco, así que tener los
  // bytes en memoria es solo un atajo para no releer el archivo. Sin
  // tope, ese atajo se volvía un problema: recorriendo una biblioteca
  // de cientos de canciones se acumulaban TODAS las imágenes en RAM
  // para siempre (decenas de MB), que es la clase de cosa por la que
  // Android termina matando la app sola. Al pasarse del tope se
  // descartan las más viejas: la próxima vez que hagan falta se
  // releen del disco, que es rápido y no vuelve a bajarlas.
  static const int _maxCaratulasEnMemoria = 60;
  final List<String> _ordenCaratulas = [];

  void _recordarCaratula(String url, Uint8List bytes) {
    _cacheCaratula[url] = bytes;
    _ordenCaratulas.remove(url);
    _ordenCaratulas.add(url);
    while (_ordenCaratulas.length > _maxCaratulasEnMemoria) {
      // `remove` (y no dejarla en null) a propósito: null significa
      // "esta canción no tiene carátula", que es otra cosa muy distinta
      // de "todavía no la tengo cargada".
      _cacheCaratula.remove(_ordenCaratulas.removeAt(0));
    }
  }

  Directory? _dirCache;

  Future<Directory> _coverDir() async {
    if (_dirCache != null) return _dirCache!;
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/id3_covers');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dirCache = dir;
    return dir;
  }

  /// Nombre de archivo seguro derivado de la URL (usamos el último
  /// segmento, que ya es único por canción — el propio nombre del
  /// archivo mp3).
  String _claveArchivo(String url) {
    final uri = Uri.tryParse(url);
    final ultimo = (uri != null && uri.pathSegments.isNotEmpty)
        ? uri.pathSegments.last
        : url;
    return ultimo.replaceAll(RegExp(r'[^\w.\-]'), '_');
  }

  /// Obtiene los bytes del MP3 (archivo local si es una canción
  /// descargada, o los primeros ~512KB por red vía HTTP Range) — el
  /// paso costoso que carátula y álbum comparten.
  Future<Uint8List?> _obtenerBytesMp3(String url) async {
    try {
      final esArchivoLocal =
          !url.startsWith('http://') && !url.startsWith('https://');

      if (esArchivoLocal) {
        final archivoLocal = File(url);
        if (!await archivoLocal.exists()) return null;
        return await archivoLocal.readAsBytes();
      }

      final response = await http.get(Uri.parse(url), headers: {
        'Range': 'bytes=0-524287'
      }).timeout(const Duration(seconds: 8));

      // 200 = el servidor ignoró el Range y mandó todo igual (también
      // sirve). 206 = sí respetó el rango (lo esperado).
      if (response.statusCode != 200 && response.statusCode != 206) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  // ========== CARÁTULA (APIC) ==========

  Future<Uint8List?> getEmbeddedCover(String url) async {
    if (_cacheCaratula.containsKey(url)) return _cacheCaratula[url];

    // 1) ¿Ya la teníamos guardada en disco de una sesión anterior?
    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      final archivoImagen = File('${dir.path}/$clave.jpg');
      final archivoSinCaratula = File('${dir.path}/$clave.nocover');

      if (await archivoSinCaratula.exists()) {
        _cacheCaratula[url] = null;
        return null;
      }
      if (await archivoImagen.exists()) {
        final bytes = await archivoImagen.readAsBytes();
        _recordarCaratula(url, bytes);
        return bytes;
      }
    } catch (_) {
      // Si falla la lectura de disco, seguimos igual por red.
    }

    // 2) No estaba en disco: parseamos los tags del MP3.
    try {
      final bytes = await _obtenerBytesMp3(url);
      if (bytes == null) {
        _cacheCaratula[url] = null;
        _marcarSinCaratula(url);
        return null;
      }

      final mp3 = MP3Instance(bytes);
      if (mp3.parseTagsSync()) {
        final tags = mp3.getMetaTags();

        // De paso, ya que parseamos los tags, guardamos álbum Y artista
        // en caché de memoria también — así getEmbeddedAlbum()/
        // getEmbeddedArtist() para esta misma canción no necesitan una
        // segunda petición de red.
        _cacheAlbum[url] = _extraerAlbum(tags);
        _cacheArtista[url] = _extraerArtista(tags);

        final apic = tags?['APIC'];
        final base64Str = apic is Map ? apic['base64'] as String? : null;
        if (base64Str != null && base64Str.isNotEmpty) {
          final imagenBytes = base64Decode(base64Str);
          _recordarCaratula(url, imagenBytes);
          _guardarEnDisco(url, imagenBytes); // no esperamos, no bloquea la UI
          return imagenBytes;
        }
      }
    } catch (_) {
      // El archivo no trae carátula incrustada, no hay red/archivo, o
      // el servidor no soporta Range — seguimos con el fallback.
    }

    _cacheCaratula[url] = null;
    _marcarSinCaratula(url);
    return null;
  }

  /// Igual que [getEmbeddedCover], pero devuelve la RUTA en disco de la
  /// imagen cacheada en vez de los bytes — útil para armar un
  /// `Uri.file(...)` que la notificación / pantalla de bloqueo pueda
  /// mostrar directamente (audio_service necesita un Uri, no bytes).
  Future<String?> getEmbeddedCoverPath(String url) async {
    final bytes = await getEmbeddedCover(url);
    if (bytes == null) return null;
    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      final archivo = File('${dir.path}/$clave.jpg');
      if (await archivo.exists()) return archivo.path;
    } catch (_) {}
    return null;
  }

  Future<void> _guardarEnDisco(String url, Uint8List bytes) async {
    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      await File('${dir.path}/$clave.jpg').writeAsBytes(bytes);
    } catch (_) {
      // Si no se pudo guardar, no pasa nada grave: solo se re-buscará
      // la próxima vez.
    }
  }

  Future<void> _marcarSinCaratula(String url) async {
    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      await File('${dir.path}/$clave.nocover').writeAsBytes(const []);
    } catch (_) {}
  }

  // ========== ÁLBUM REAL (TALB) ==========

  String? _extraerAlbum(Map<String, dynamic>? tags) {
    if (tags == null || !tags.containsKey('Album')) return null;
    final valor = tags['Album'];

    // Validación segura de tipos para prevenir errores inesperados (TypeError)
    String? album;
    if (valor is String) {
      album = valor;
    } else if (valor is Map && valor.containsKey('text')) {
      album = valor['text']?.toString();
    } else {
      album = valor?.toString();
    }

    if (album == null) return null;
    final limpio = album.trim();
    return limpio.isEmpty ? null : limpio;
  }

  /// Devuelve el nombre de álbum REAL que trae el propio MP3 (tag
  /// ID3 "Album"/TALB), o `null` si no tiene ese tag. A diferencia de
  /// la carátula, esto se guarda en disco como texto plano (un
  /// archivo `.album` chiquito), separado del caché de imagen.
  Future<String?> getEmbeddedAlbum(String url) async {
    if (_cacheAlbum.containsKey(url)) return _cacheAlbum[url];

    // 1) ¿Ya lo guardamos en disco de una sesión anterior?
    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      final archivoAlbum = File('${dir.path}/$clave.album');
      final archivoSinAlbum = File('${dir.path}/$clave.noalbum');

      if (await archivoSinAlbum.exists()) {
        _cacheAlbum[url] = null;
        return null;
      }
      if (await archivoAlbum.exists()) {
        final texto = await archivoAlbum.readAsString();
        _cacheAlbum[url] = texto;
        return texto;
      }
    } catch (_) {
      // Si falla la lectura de disco, seguimos igual por red.
    }

    // 2) No estaba en disco: parseamos los tags del MP3.
    try {
      final bytes = await _obtenerBytesMp3(url);
      if (bytes == null) {
        _cacheAlbum[url] = null;
        _marcarSinAlbum(url);
        return null;
      }

      final mp3 = MP3Instance(bytes);
      if (mp3.parseTagsSync()) {
        final tags = mp3.getMetaTags();
        final album = _extraerAlbum(tags);
        _cacheAlbum[url] = album;
        if (album != null) {
          _guardarAlbumEnDisco(url, album); // no esperamos, no bloquea la UI
          return album;
        }
      }
    } catch (_) {
      // El archivo no trae el tag, no hay red/archivo, o el servidor
      // no soporta Range — seguimos con el fallback en quien llame.
    }

    _cacheAlbum[url] = null;
    _marcarSinAlbum(url);
    return null;
  }

  Future<void> _guardarAlbumEnDisco(String url, String album) async {
    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      await File('${dir.path}/$clave.album').writeAsString(album);
    } catch (_) {}
  }

  Future<void> _marcarSinAlbum(String url) async {
    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      await File('${dir.path}/$clave.noalbum').writeAsBytes(const []);
    } catch (_) {}
  }

  // ========== ARTISTA REAL (TPE1) ==========
  //
  // Mismo patrón que "ÁLBUM REAL" de arriba. Se agregó porque
  // `DriveService` solo puede adivinar el artista a partir del nombre
  // del archivo (ej. "Artista - Canción.mp3") -- cuando el archivo no
  // sigue ese patrón, queda como "Artista Desconocido" para siempre,
  // aunque el propio MP3 sí traiga el artista real en su tag ID3
  // (TPE1). Confirmado el caso real: "Runnin' Down A Dream.mp3" (sin
  // " - " en el nombre) se mostraba como "Artista Desconocido" en vez
  // de "Tom Petty".

  String? _extraerArtista(Map<String, dynamic>? tags) {
    if (tags == null || !tags.containsKey('Artist')) return null;
    final valor = tags['Artist'];

    String? artista;
    if (valor is String) {
      artista = valor;
    } else if (valor is Map && valor.containsKey('text')) {
      artista = valor['text']?.toString();
    } else {
      artista = valor?.toString();
    }

    if (artista == null) return null;
    final limpio = artista.trim();
    return limpio.isEmpty ? null : limpio;
  }

  /// Devuelve el artista REAL que trae el propio MP3 (tag ID3
  /// "Artist"/TPE1), o `null` si no tiene ese tag.
  Future<String?> getEmbeddedArtist(String url) async {
    if (_cacheArtista.containsKey(url)) return _cacheArtista[url];

    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      final archivoArtista = File('${dir.path}/$clave.artist');
      final archivoSinArtista = File('${dir.path}/$clave.noartist');

      if (await archivoSinArtista.exists()) {
        _cacheArtista[url] = null;
        return null;
      }
      if (await archivoArtista.exists()) {
        final texto = await archivoArtista.readAsString();
        _cacheArtista[url] = texto;
        return texto;
      }
    } catch (_) {
      // Si falla la lectura de disco, seguimos igual por red.
    }

    try {
      final bytes = await _obtenerBytesMp3(url);
      if (bytes == null) {
        _cacheArtista[url] = null;
        _marcarSinArtista(url);
        return null;
      }

      final mp3 = MP3Instance(bytes);
      if (mp3.parseTagsSync()) {
        final tags = mp3.getMetaTags();
        final artista = _extraerArtista(tags);
        _cacheArtista[url] = artista;
        if (artista != null) {
          _guardarArtistaEnDisco(
              url, artista); // no esperamos, no bloquea la UI
          return artista;
        }
      }
    } catch (_) {
      // El archivo no trae el tag, no hay red/archivo, o el servidor
      // no soporta Range -- seguimos con el fallback en quien llame.
    }

    _cacheArtista[url] = null;
    _marcarSinArtista(url);
    return null;
  }

  Future<void> _guardarArtistaEnDisco(String url, String artista) async {
    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      await File('${dir.path}/$clave.artist').writeAsString(artista);
    } catch (_) {}
  }

  Future<void> _marcarSinArtista(String url) async {
    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      await File('${dir.path}/$clave.noartist').writeAsBytes(const []);
    } catch (_) {}
  }
}
