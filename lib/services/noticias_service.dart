import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/noticia.dart';
import '../utils/rss_parser.dart';

/// Se lanza cuando no se pudo traer las noticias, con un mensaje ya
/// escrito para mostrarle al usuario. Separar "no hay internet" de "el
/// servidor falló" importa: son dos problemas distintos y el usuario
/// puede hacer algo distinto con cada uno.
class ErrorNoticias implements Exception {
  final String mensaje;
  final bool sinConexion;
  const ErrorNoticias(this.mensaje, {this.sinConexion = false});

  @override
  String toString() => mensaje;
}

/// Una categoría de noticias, con el texto que se le pide al buscador.
class CategoriaNoticias {
  final String nombre;
  final String consulta;
  const CategoriaNoticias(this.nombre, this.consulta);
}

/// Trae noticias desde el RSS de Google Noticias.
///
/// Se eligió esa fuente porque es gratuita, no pide clave de API, no
/// tiene límite de consultas y funciona en español: con un mismo
/// mecanismo se cubren todas las categorías cambiando solo el texto de
/// búsqueda.
///
/// La contra, dicha de frente: no es una API oficial documentada, así
/// que Google podría cambiarla. Si eso pasa, los tests de
/// `rss_parser.dart` son los que lo van a delatar, y el plan B son los
/// RSS propios de cada diario, que son estables pero hay que elegirlos
/// uno por uno.
class NoticiasService {
  // Mismo patrón exacto que `JamendoService` y `LyricsService`: el
  // cliente entra por el constructor privado para poder inyectar uno
  // falso en los tests, y queda `final`. Antes acá el campo era mutable
  // y con inicializador propio, así que `.testable()` creaba un cliente
  // de red real y lo tiraba al instante.
  NoticiasService._({http.Client? client}) : _client = client ?? http.Client();

  static final NoticiasService instance = NoticiasService._();

  /// Permite inyectar un cliente falso en los tests.
  factory NoticiasService.testable(http.Client client) =>
      NoticiasService._(client: client);

  final http.Client _client;

  /// Las categorías que pidió el profesor, más música de los 60 a los 90
  /// que es lo que escucha el dueño de la app.
  static const List<CategoriaNoticias> categorias = [
    CategoriaNoticias('Negocios internacionales', 'negocios internacionales'),
    CategoriaNoticias(
        'Comercio global', 'comercio internacional exportaciones'),
    CategoriaNoticias('Logística', 'logística transporte de carga'),
    CategoriaNoticias('Cadena de suministro', 'cadena de suministro'),
    CategoriaNoticias('Contratos', 'contratos internacionales comercio'),
    CategoriaNoticias('Tecnología', 'tecnología nanotecnología robótica'),
    CategoriaNoticias('Música', 'rock clásico música años 70 80'),
  ];

  // Las noticias quedan guardadas por categoría para no volver a pedir
  // lo mismo al cambiar de pestaña y volver. Con fecha, porque son
  // NOTICIAS: sin vencimiento, una app abierta desde ayer seguía
  // mostrando las de ayer y parecía que no pasaba nada en el mundo.
  static const Duration _duracionCache = Duration(minutes: 30);
  final Map<String, List<Noticia>> _cache = {};
  final Map<String, DateTime> _cacheFecha = {};

  /// [forzar] salta la caché, para el gesto de "deslizar para
  /// actualizar".
  Future<List<Noticia>> obtener(
    CategoriaNoticias categoria, {
    bool forzar = false,
  }) async {
    final guardadas = _cache[categoria.nombre];
    final fecha = _cacheFecha[categoria.nombre];
    if (!forzar &&
        guardadas != null &&
        fecha != null &&
        DateTime.now().difference(fecha) < _duracionCache) {
      return guardadas;
    }

    final url = Uri.https('news.google.com', '/rss/search', {
      'q': categoria.consulta,
      'hl': 'es-419',
      'gl': 'PE',
      'ceid': 'PE:es-419',
    });

    try {
      final respuesta =
          await _client.get(url).timeout(const Duration(seconds: 12));
      if (respuesta.statusCode != 200) {
        throw ErrorNoticias(
          'El servicio de noticias respondió ${respuesta.statusCode}. '
          'Probá de nuevo en un rato.',
        );
      }
      // `bodyBytes` y no `body`: el feed viene en UTF-8 y leerlo como
      // texto directo rompe los acentos y las eñes.
      final noticias = parsearRssONulo(utf8Seguro(respuesta.bodyBytes));
      if (noticias == null) {
        // No era un feed: una página de error devuelta con código 200,
        // o XML roto. Eso sí es un fallo y hay que decirlo.
        throw const ErrorNoticias(
          'El servicio de noticias devolvió algo que no se pudo leer. '
          'Probá de nuevo en un rato.',
        );
      }
      // Una búsqueda sin resultados NO es un error: el servidor
      // contestó bien, simplemente no hay nada de ese tema ahora. Antes
      // los dos casos se trataban igual, así que la pantalla no podía
      // distinguirlos. Tampoco se guarda en caché, para que
      // "Reintentar" vuelva a consultar de verdad.
      if (noticias.isNotEmpty) {
        _cache[categoria.nombre] = noticias;
        _cacheFecha[categoria.nombre] = DateTime.now();
      }
      return noticias;
    } on SocketException {
      throw const ErrorNoticias(
        'No hay conexión a internet. Conectate y volvé a intentar.',
        sinConexion: true,
      );
    } on TimeoutException {
      throw const ErrorNoticias(
        'La conexión está muy lenta y no se pudieron cargar las noticias.',
        sinConexion: true,
      );
    } on http.ClientException {
      throw const ErrorNoticias(
        'No se pudo conectar con el servicio de noticias. Revisá tu conexión.',
        sinConexion: true,
      );
    }
  }
}

/// Decodifica como UTF-8 y, si los bytes no son UTF-8 válido, cae en
/// latin-1 en vez de reventar. Sin esto, un feed mal codificado tiraría
/// la pantalla entera abajo por un acento.
String utf8Seguro(List<int> bytes) {
  try {
    return const Utf8Decoder().convert(bytes);
  } catch (_) {
    return const Latin1Decoder().convert(bytes);
  }
}
