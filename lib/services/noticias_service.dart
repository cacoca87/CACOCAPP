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
  NoticiasService._();
  static final NoticiasService instance = NoticiasService._();

  /// Permite inyectar un cliente falso en los tests, igual que hacen
  /// `JamendoService` y `LyricsService`.
  NoticiasService.testable(http.Client cliente) : _cliente = cliente;

  http.Client _cliente = http.Client();

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

  final Map<String, List<Noticia>> _cache = {};

  /// [forzar] salta la caché, para el gesto de "deslizar para
  /// actualizar".
  Future<List<Noticia>> obtener(
    CategoriaNoticias categoria, {
    bool forzar = false,
  }) async {
    if (!forzar && _cache.containsKey(categoria.nombre)) {
      return _cache[categoria.nombre]!;
    }

    final url = Uri.https('news.google.com', '/rss/search', {
      'q': categoria.consulta,
      'hl': 'es-419',
      'gl': 'PE',
      'ceid': 'PE:es-419',
    });

    try {
      final respuesta =
          await _cliente.get(url).timeout(const Duration(seconds: 12));
      if (respuesta.statusCode != 200) {
        throw ErrorNoticias(
          'El servicio de noticias respondió ${respuesta.statusCode}. '
          'Probá de nuevo en un rato.',
        );
      }
      // `bodyBytes` y no `body`: el feed viene en UTF-8 y leerlo como
      // texto directo rompe los acentos y las eñes.
      final noticias = parsearRss(utf8Seguro(respuesta.bodyBytes));
      if (noticias.isEmpty) {
        throw const ErrorNoticias(
          'No se encontraron noticias de esta categoría ahora mismo.',
        );
      }
      _cache[categoria.nombre] = noticias;
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

  void limpiarCache() => _cache.clear();
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
