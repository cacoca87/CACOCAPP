import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:id3/id3.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/huella_de_texto.dart';
import '../utils/id3_tags.dart';
import '../utils/ruta_de_archivo.dart';
import '../utils/una_sola_vez.dart';

/// Extrae metadata REAL incrustada en el propio MP3 (tags ID3v2):
/// carátula (frame APIC), nombre de álbum (TALB) y artista (TPE1) --
/// tal como lo hace un reproductor profesional, sin necesitar servidor
/// propio ni descargar el archivo completo.
///
/// Solo pedimos los primeros ~512KB vía HTTP Range, donde normalmente
/// viven los tags ID3v2 (van al inicio del archivo). R2/Cloudflare
/// soporta peticiones por rango igual que cualquier bucket S3.
///
/// Los tres comparten el mismo parseo -- así que si `SongCover` ya pidió
/// la carátula de una canción, pedir después su álbum o su artista es
/// prácticamente gratis (no hay una segunda petición de red).
///
/// Todo se guarda también en disco (carpeta de caché de la app): antes,
/// cerrar la app por completo perdía todo el trabajo hecho y tocaba
/// re-descargar/re-leer el ID3 de cada canción otra vez. Ahora la
/// primera vez cuesta red; las siguientes son instantáneas.
class Id3CoverService {
  // Mismo patrón que el resto de los servicios: el cliente HTTP entra
  // por el constructor privado para poder probar esta clase sin red
  // real. Sin esto no habia forma de escribir un test para el fallo de
  // cache que dejaba toda la biblioteca en "Artista Desconocido".
  Id3CoverService._({http.Client? client}) : _client = client ?? http.Client();

  /// Instancia real que usa el resto de la app.
  static final Id3CoverService instance = Id3CoverService._();

  /// SOLO PARA TESTS: permite inyectar un cliente falso.
  factory Id3CoverService.testable(http.Client client) =>
      Id3CoverService._(client: client);

  final http.Client _client;

  // Lo que se recuerda de cada canción entre pantalla y pantalla. Son
  // todos textos cortos: la RUTA del archivo de la tapa, no la tapa.
  //
  // Antes acá se guardaban los bytes de las imágenes, con un tope de 60
  // y una lista aparte para ir descartando las más viejas. Eso era
  // necesario porque si no, recorrer una biblioteca de cientos de
  // canciones acumulaba TODAS las imágenes en memoria (decenas de MB),
  // que es la clase de cosa por la que Android termina matando la app
  // sola.
  //
  // Guardando la ruta en vez de los bytes, el problema desaparece de
  // raíz y además se gana algo mejor: quien dibuja la tapa le pasa el
  // ARCHIVO a Flutter, y entonces la memoria de imágenes de Flutter
  // --que ya sabe descartar lo que no se está viendo-- se encarga sola.
  // Un mapa de rutas no necesita tope: mil canciones son unos pocos
  // kilobytes de texto.
  final Map<String, String?> _cacheRuta = {};
  final Map<String, String?> _cacheAlbum = {};
  final Map<String, String?> _cacheArtista = {};
  final Map<String, String?> _cacheTitulo = {};

  // Se guarda la PROMESA de la carpeta, no la carpeta ya lista.
  //
  // La diferencia importa porque preparar la carpeta incluye una
  // limpieza de marcas viejas, y al abrir la app hay decenas de
  // canciones pidiendo su carátula al mismo tiempo. Guardando la
  // carpeta terminada, todas las que llegaban ANTES de que la primera
  // terminara se ponían a prepararla de nuevo por su cuenta, y algunas
  // llegaban a leer marcas que la limpieza estaba justo borrando.
  // Guardando la promesa, la preparan una sola vez y las demás esperan
  // esa misma.
  Future<Directory>? _prepararCarpeta;

  Future<Directory> _coverDir() => _prepararCarpeta ??= _prepararCarpetaAhora();

  Future<Directory> _prepararCarpetaAhora() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/id3_covers');
    if (!await dir.exists()) await dir.create(recursive: true);
    await _borrarLasMarcasDeLaReglaVieja(dir);
    return dir;
  }

  /// Borra, UNA sola vez, las marcas de "esta canción no tiene
  /// carátula / álbum / artista" que quedaron escritas por el fallo
  /// corregido en la vuelta 29.
  ///
  /// Hasta entonces, una apertura de la app sin internet anotaba esas
  /// marcas como si fueran definitivas, y como se leen ANTES de pedir
  /// nada, la biblioteca se quedaba con el dibujito gris y "Artista
  /// Desconocido" para siempre, aunque el MP3 sí trajera los datos.
  /// Corregir la regla no alcanzaba: lo ya escrito seguía ahí.
  ///
  /// Se borran SOLO las marcas de "no hay". Las carátulas y los textos
  /// que sí se encontraron se conservan: volver a bajarlos costaría
  /// datos móviles sin ninguna necesidad.
  ///
  /// El aviso de que ya se hizo es un archivito en la misma carpeta,
  /// para no arrastrar una dependencia más solo por esto.
  Future<void> _borrarLasMarcasDeLaReglaVieja(Directory dir) async {
    try {
      final yaSeHizo = File('${dir.path}/.marcas_revisadas_v2');
      if (await yaSeHizo.exists()) return;

      const marcasDeNoHay = [
        '.nocover',
        '.noalbum',
        '.noartist',
        '.notitle',
      ];
      await for (final archivo in dir.list()) {
        if (archivo is! File) continue;
        if (marcasDeNoHay.any(archivo.path.endsWith)) {
          await archivo.delete();
        }
      }
      await yaSeHizo.writeAsBytes(const []);
    } catch (_) {
      // Si no se pudo, no pasa nada grave: la app funciona igual, solo
      // que esas canciones siguen sin su carátula hasta la próxima.
    }
  }

  /// Con qué nombre se guarda en la caché lo que se sacó de esta
  /// canción: el nombre de su archivo, limpio de caracteres raros, y
  /// para las del celular además una huella de la ruta completa (ver
  /// el porqué abajo).
  String _claveArchivo(String url) {
    final uri = Uri.tryParse(url);
    final ultimo = (uri != null && uri.pathSegments.isNotEmpty)
        ? uri.pathSegments.last
        : url;
    final limpio = ultimo.replaceAll(RegExp(r'[^\w.\-]'), '_');

    // Para los archivos DEL CELULAR se agrega una huella de la ruta
    // completa.
    //
    // Las canciones del servidor viven todas juntas en un mismo lugar,
    // así que su nombre de archivo ya las distingue. Las del celular
    // no: están repartidas en carpetas, y es de lo más común tener
    // "/Music/Rock/01 - Intro.mp3" y "/Music/Jazz/01 - Intro.mp3". Con
    // el nombre solo, las dos caían en el mismo lugar de la caché y la
    // segunda terminaba mostrando la carátula, el álbum y el artista de
    // la primera.
    //
    // La huella se agrega SOLO a las locales a propósito: si se le
    // pusiera a todas, las carátulas del servidor que ya están
    // guardadas dejarían de encontrarse y habría que volver a bajarlas
    // --medio megabyte por canción de datos móviles-- sin ninguna
    // necesidad.
    if (rutaDeArchivoDe(url) == null) return limpio;
    return '${limpio}_${huellaCorta(url)}';
  }

  /// Obtiene los bytes del MP3 (archivo local si es una canción
  /// descargada, o los primeros ~512KB por red vía HTTP Range) — el
  /// paso costoso que carátula, álbum y artista comparten.
  ///
  /// Devuelve tambien, por separado, si se pudo leer el archivo. La
  /// diferencia importa: "lo lei entero y no trae caratula" se puede
  /// anotar en disco para siempre, pero "no habia internet" no. Antes
  /// los dos casos eran el mismo `null`, asi que abrir la app una sola
  /// vez con mala conexion dejaba la biblioteca entera marcada como
  /// "sin caratula" y "Artista Desconocido" de forma permanente.
  ///
  /// SE COMPARTE LA MISMA DESCARGA ENTRE QUIENES LA PIDAN A LA VEZ
  ///
  /// Al abrir la app pasan dos cosas al mismo tiempo: la lista empieza a
  /// pedir la carátula de cada canción que se ve, y por detrás corre el
  /// repaso que completa el álbum y el artista de toda la biblioteca.
  /// Las dos cosas necesitan exactamente los mismos 512 KB del mismo
  /// MP3, y cada una los bajaba por su cuenta: el doble de datos
  /// móviles, por nada. Con decenas de canciones en pantalla eso son
  /// varios megas de más en el primer arranque.
  ///
  /// Anotando la descarga que ya está en curso, el segundo que la pida
  /// espera la misma en vez de abrir otra. Se usa `UnaSolaVez`, que es
  /// el mismo mecanismo que junta los pedidos de tapa y los de iTunes.
  ///
  /// Ojo con esto: la anotación se borra al terminar. Si quedara, los
  /// bytes de TODA la biblioteca se acumularían en memoria, que es
  /// justo lo que se quiere evitar.
  final UnaSolaVez<({Uint8List? bytes, bool seLeyo})> _juntarDescargas =
      UnaSolaVez<({Uint8List? bytes, bool seLeyo})>();

  Future<({Uint8List? bytes, bool seLeyo})> _obtenerBytesMp3(String url) =>
      _juntarDescargas.hacer(url, () => _bajarBytesMp3(url));

  Future<({Uint8List? bytes, bool seLeyo})> _bajarBytesMp3(String url) async {
    try {
      // Las canciones descargadas vienen como `file:///...`, que es una
      // dirección y no una ruta. Ver `utils/ruta_de_archivo.dart`.
      final ruta = rutaDeArchivoDe(url);
      if (ruta != null) {
        final archivoLocal = File(ruta);
        if (!await archivoLocal.exists()) return (bytes: null, seLeyo: false);
        return (bytes: await archivoLocal.readAsBytes(), seLeyo: true);
      }

      final response = await _client.get(Uri.parse(url), headers: {
        'Range': 'bytes=0-524287'
      }).timeout(const Duration(seconds: 8));

      // 200 = el servidor ignoró el Range y mandó todo igual (también
      // sirve). 206 = sí respetó el rango (lo esperado).
      if (response.statusCode != 200 && response.statusCode != 206) {
        return (bytes: null, seLeyo: false);
      }
      return (bytes: response.bodyBytes, seLeyo: true);
    } catch (_) {
      return (bytes: null, seLeyo: false);
    }
  }

  // ========== CARÁTULA (APIC) ==========

  /// La RUTA en disco de la carátula incrustada en el MP3, o `null` si
  /// esa canción no trae ninguna.
  ///
  /// Es la forma PRINCIPAL de pedir una carátula, y devuelve una ruta y
  /// no los bytes por dos motivos:
  ///
  ///  * La notificación de la pantalla de bloqueo necesita un archivo
  ///    de verdad (`audio_service` quiere un `Uri`, no bytes).
  ///  * Quien la dibuja en pantalla le puede pasar el ARCHIVO a
  ///    Flutter. Flutter tiene su propia memoria de imágenes, que
  ///    reconoce dos pedidos del mismo archivo como la misma imagen y
  ///    descarta sola lo que ya no se ve. Pasándole bytes, cada vez que
  ///    una fila volvía a aparecer al desplazar la lista era una imagen
  ///    nueva para Flutter: la decodificaba de cero, otra vez.
  ///
  /// El archivo queda escrito ANTES de que esto devuelva la ruta.
  /// Parece obvio y no lo era: la escritura se lanzaba sin esperarla, y
  /// enseguida se comprobaba si el archivo existía. La comprobación
  /// ganaba casi siempre, así que la primera vez que ponías una canción
  /// la respuesta era `null` y la tapa del bloqueo terminaba
  /// buscándose en iTunes -- un pedido de red de más, para conseguir
  /// una imagen que ya estaba adentro del propio MP3.
  /// Junta los pedidos simultáneos de la misma canción, que en esta app
  /// son la norma: la fila de la lista, el mini reproductor de abajo y
  /// los carruseles de Inicio pueden estar mostrando la misma canción a
  /// la vez, y los cuatro piden su tapa en el mismo instante. Ver
  /// `utils/una_sola_vez.dart`.
  final UnaSolaVez<String?> _juntarTapas = UnaSolaVez<String?>();

  Future<String?> getEmbeddedCoverPath(String url) {
    if (_cacheRuta.containsKey(url)) return Future.value(_cacheRuta[url]);
    return _juntarTapas.hacer(url, () => _resolverRutaDeTapa(url));
  }

  /// `true` si YA se sabe, sin esperar nada, si esta canción tiene
  /// carátula incrustada o no.
  ///
  /// Existe para que dibujar una tapa que ya se conoce no tenga que
  /// pasar por una espera. Hasta la más corta cuesta: quien dibuja se
  /// queda un cuadro entero mostrando la ruedita de "cargando" antes de
  /// poder poner la imagen, y al desplazar una lista larga eso es un
  /// parpadeo de ruedas en cada fila que aparece, aunque estén todas
  /// resueltas desde hace rato.
  ///
  /// Se pregunta primero con esto, y solo si dice que no se sabe se
  /// llama a [getEmbeddedCoverPath] y se espera.
  bool seSabeLaRuta(String url) => _cacheRuta.containsKey(url);

  /// La ruta ya conocida. Solo tiene sentido si [seSabeLaRuta] dijo que
  /// sí: `null` acá significa "esta canción no trae carátula", no
  /// "todavía no lo sé".
  String? rutaYaConocida(String url) => _cacheRuta[url];

  Future<String?> _resolverRutaDeTapa(String url) async {
    if (_cacheRuta.containsKey(url)) return _cacheRuta[url];

    final clave = _claveArchivo(url);

    // 1) ¿Ya la teníamos guardada en disco de una sesión anterior?
    try {
      final dir = await _coverDir();
      final archivoImagen = File('${dir.path}/$clave.jpg');
      final archivoSinCaratula = File('${dir.path}/$clave.nocover');

      if (await archivoSinCaratula.exists()) {
        _cacheRuta[url] = null;
        return null;
      }
      if (await archivoImagen.exists()) {
        _cacheRuta[url] = archivoImagen.path;
        return archivoImagen.path;
      }
    } catch (_) {
      // Si falla la lectura de disco, seguimos igual por red.
    }

    // 2) No estaba en disco: parseamos los tags del MP3.
    var seLeyoElArchivo = false;
    try {
      // Acá NO hace falta volver a mirar el caché después de esperar,
      // como sí hacen el álbum, el artista y el título más abajo: a
      // esos pueden entrarles dos pedidos a la vez, pero a este no,
      // porque `getEmbeddedCoverPath` ya los junta con `UnaSolaVez`.
      // Llegó a estar puesto igual, con un comentario que explicaba una
      // situación que no podía pasar.
      final lectura = await _obtenerBytesMp3(url);
      seLeyoElArchivo = lectura.seLeyo;
      final bytes = lectura.bytes;
      if (bytes == null) {
        _cacheRuta[url] = null;
        if (seLeyoElArchivo) unawaited(_marcarSinCaratula(url));
        return null;
      }

      final mp3 = MP3Instance(bytes);
      if (mp3.parseTagsSync()) {
        final tags = mp3.getMetaTags();

        // Ya que se parsearon los tags, se guardan álbum, artista y
        // título (memoria y disco) para que pedirlos después no vuelva
        // a bajar el archivo.
        _recordarTags(url, tags);

        final apic = tags?['APIC'];
        final base64Str = apic is Map ? apic['base64'] as String? : null;
        if (base64Str != null && base64Str.isNotEmpty) {
          final imagenBytes = base64Decode(base64Str);
          // Se ESPERA la escritura: la ruta que se devuelve tiene que
          // apuntar a un archivo que ya está completo.
          final ruta = await _guardarEnDisco(clave, imagenBytes);
          _cacheRuta[url] = ruta;
          return ruta;
        }
      }
    } catch (_) {
      // El archivo no trae carátula incrustada, no hay red/archivo, o
      // el servidor no soporta Range — seguimos con el fallback.
    }

    _cacheRuta[url] = null;
    if (seLeyoElArchivo) unawaited(_marcarSinCaratula(url));
    return null;
  }

  /// Los bytes de la carátula, para quien de verdad los necesite.
  ///
  /// Hoy no la usa nadie para DIBUJAR: para eso está
  /// [getEmbeddedCoverPath], que deja que Flutter maneje la memoria de
  /// la imagen. Se conserva porque es la forma más directa de
  /// comprobar en un test que la carátula se leyó bien.
  Future<Uint8List?> getEmbeddedCover(String url) async {
    final ruta = await getEmbeddedCoverPath(url);
    if (ruta == null) return null;
    try {
      return await File(ruta).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Escribe la imagen y devuelve su ruta, o `null` si no se pudo.
  Future<String?> _guardarEnDisco(String clave, Uint8List bytes) async {
    try {
      final dir = await _coverDir();
      final archivo = File('${dir.path}/$clave.jpg');
      await archivo.writeAsBytes(bytes);
      return archivo.path;
    } catch (_) {
      // Si no se pudo guardar, no pasa nada grave: solo se re-buscará
      // la próxima vez.
      return null;
    }
  }

  Future<void> _marcarSinCaratula(String url) async {
    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      await File('${dir.path}/$clave.nocover').writeAsBytes(const []);
    } catch (_) {}
  }

  /// Guarda de una sola lectura lo que trae el MP3 --carátula aparte:
  /// álbum, artista
  /// y título -- de un mismo parseo, en memoria y en disco.
  ///
  /// Existe porque los cuatro caminos que leen tags (carátula, álbum,
  /// artista y título) salen del MISMO archivo descargado, pero cada uno
  /// guardaba solo lo suyo. Resultado: escanear la biblioteca pedía el
  /// álbum de una canción (512 KB por red), y enseguida el artista de la
  /// misma canción, bajando otros 512 KB para releer exactamente los
  /// mismos bytes. Con cientos de canciones eso es el doble de datos
  /// móviles en el primer escaneo, y encima la carátula los guardaba solo
  /// en memoria, así que al reabrir la app se volvían a bajar.
  /// Las seis escrituras van SIN esperar, a propósito: lo que importa
  /// --el dato-- ya quedó en memoria en la línea de arriba, y la
  /// pantalla lo puede usar ya. Guardarlo en el disco es para la
  /// próxima vez que se abra la app, y no tiene por qué demorar nada.
  void _recordarTags(String url, Map<String, dynamic>? tags) {
    final album = _extraerAlbum(tags);
    _cacheAlbum[url] = album;
    unawaited(album != null
        ? _guardarAlbumEnDisco(url, album)
        : _marcarSinAlbum(url));

    final artista = _extraerArtista(tags);
    _cacheArtista[url] = artista;
    unawaited(artista != null
        ? _guardarArtistaEnDisco(url, artista)
        : _marcarSinArtista(url));

    final titulo = _extraerTitulo(tags);
    _cacheTitulo[url] = titulo;
    unawaited(titulo != null
        ? _guardarTituloEnDisco(url, titulo)
        : _marcarSinTitulo(url));
  }

  // ========== TÍTULO REAL (TIT2) ==========
  //
  // Se agregó porque el nombre del archivo a veces no dice cómo se
  // llama la canción. Caso comprobado en la biblioteca: varios temas
  // del disco "Libre" de Amén llegaban con el nombre de la BANDA, así
  // que la app mostraba tres canciones distintas todas llamadas
  // "Amén". Con el título equivocado la letra tampoco se puede buscar,
  // porque se pide una canción que no existe.

  String? _extraerTitulo(Map<String, dynamic>? tags) =>
      leerTagDeTexto(tags, 'Title');

  /// Devuelve el título REAL que trae el propio MP3 (tag ID3
  /// "Title"/TIT2), o `null` si no lo trae.
  Future<String?> getEmbeddedTitle(String url) async {
    if (_cacheTitulo.containsKey(url)) return _cacheTitulo[url];

    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      final archivoTitulo = File('${dir.path}/$clave.title');
      final archivoSinTitulo = File('${dir.path}/$clave.notitle');

      if (await archivoSinTitulo.exists()) {
        _cacheTitulo[url] = null;
        return null;
      }
      if (await archivoTitulo.exists()) {
        final texto = await archivoTitulo.readAsString();
        _cacheTitulo[url] = texto;
        return texto;
      }
    } catch (_) {
      // Si falla la lectura de disco, seguimos igual por red.
    }

    var seLeyoElArchivo = false;
    try {
      final lectura = await _obtenerBytesMp3(url);
      // Mientras se esperaba la descarga, otro pedido de la MISMA
      // canción pudo haber parseado ya los tags y dejado esto
      // resuelto: la lista, el mini reproductor y la pantalla del
      // reproductor piden la tapa de la canción que suena a la vez.
      // Sin esta comprobación se volvía a parsear medio megabyte para
      // llegar al mismo resultado.
      if (_cacheTitulo.containsKey(url)) return _cacheTitulo[url];
      seLeyoElArchivo = lectura.seLeyo;
      final bytes = lectura.bytes;
      if (bytes == null) {
        _cacheTitulo[url] = null;
        if (seLeyoElArchivo) unawaited(_marcarSinTitulo(url));
        return null;
      }

      final mp3 = MP3Instance(bytes);
      if (mp3.parseTagsSync()) {
        _recordarTags(url, mp3.getMetaTags());
        return _cacheTitulo[url];
      }
    } catch (_) {
      // El archivo no trae el tag, no hay red/archivo, o el servidor
      // no soporta Range -- seguimos con el fallback en quien llame.
    }

    _cacheTitulo[url] = null;
    if (seLeyoElArchivo) unawaited(_marcarSinTitulo(url));
    return null;
  }

  Future<void> _guardarTituloEnDisco(String url, String titulo) async {
    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      await File('${dir.path}/$clave.title').writeAsString(titulo);
    } catch (_) {}
  }

  Future<void> _marcarSinTitulo(String url) async {
    try {
      final dir = await _coverDir();
      final clave = _claveArchivo(url);
      await File('${dir.path}/$clave.notitle').writeAsBytes(const []);
    } catch (_) {}
  }
  // ========== ÁLBUM REAL (TALB) ==========

  String? _extraerAlbum(Map<String, dynamic>? tags) =>
      leerTagDeTexto(tags, 'Album');

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
    var seLeyoElArchivo = false;
    try {
      final lectura = await _obtenerBytesMp3(url);
      // Mientras se esperaba la descarga, otro pedido de la MISMA
      // canción pudo haber parseado ya los tags y dejado esto
      // resuelto: la lista, el mini reproductor y la pantalla del
      // reproductor piden la tapa de la canción que suena a la vez.
      // Sin esta comprobación se volvía a parsear medio megabyte para
      // llegar al mismo resultado.
      if (_cacheAlbum.containsKey(url)) return _cacheAlbum[url];
      seLeyoElArchivo = lectura.seLeyo;
      final bytes = lectura.bytes;
      if (bytes == null) {
        _cacheAlbum[url] = null;
        if (seLeyoElArchivo) unawaited(_marcarSinAlbum(url));
        return null;
      }

      final mp3 = MP3Instance(bytes);
      if (mp3.parseTagsSync()) {
        _recordarTags(url, mp3.getMetaTags());
        return _cacheAlbum[url];
      }
    } catch (_) {
      // El archivo no trae el tag, no hay red/archivo, o el servidor
      // no soporta Range — seguimos con el fallback en quien llame.
    }

    _cacheAlbum[url] = null;
    if (seLeyoElArchivo) unawaited(_marcarSinAlbum(url));
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

  String? _extraerArtista(Map<String, dynamic>? tags) =>
      leerTagDeTexto(tags, 'Artist');

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

    var seLeyoElArchivo = false;
    try {
      final lectura = await _obtenerBytesMp3(url);
      // Mientras se esperaba la descarga, otro pedido de la MISMA
      // canción pudo haber parseado ya los tags y dejado esto
      // resuelto: la lista, el mini reproductor y la pantalla del
      // reproductor piden la tapa de la canción que suena a la vez.
      // Sin esta comprobación se volvía a parsear medio megabyte para
      // llegar al mismo resultado.
      if (_cacheArtista.containsKey(url)) return _cacheArtista[url];
      seLeyoElArchivo = lectura.seLeyo;
      final bytes = lectura.bytes;
      if (bytes == null) {
        _cacheArtista[url] = null;
        if (seLeyoElArchivo) unawaited(_marcarSinArtista(url));
        return null;
      }

      final mp3 = MP3Instance(bytes);
      if (mp3.parseTagsSync()) {
        _recordarTags(url, mp3.getMetaTags());
        return _cacheArtista[url];
      }
    } catch (_) {
      // El archivo no trae el tag, no hay red/archivo, o el servidor
      // no soporta Range -- seguimos con el fallback en quien llame.
    }

    _cacheArtista[url] = null;
    if (seLeyoElArchivo) unawaited(_marcarSinArtista(url));
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
