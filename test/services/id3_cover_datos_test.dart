import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:CACOCAPP/services/id3_cover_service.dart';
import 'package:CACOCAPP/utils/tamano_etiqueta_id3.dart';

/// Cuántos datos móviles gasta leer los títulos de la biblioteca.
///
/// Antes se pedían 512 KB de CADA canción, siempre. Con 160 temas eso
/// son ochenta megabytes la primera vez que se abre la app, para leer
/// unos títulos y unas carátulas. En un celular con datos contados, eso
/// no es un detalle.
///
/// Acá se comprueba lo que se le pide de verdad al servidor.

class _CarpetaFalsa extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _CarpetaFalsa(this.raiz);
  final String raiz;

  @override
  Future<String?> getTemporaryPath() async => raiz;
}

/// Una etiqueta ID3v2 de [tamanoDelContenido] bytes, rellena.
List<int> _mp3ConEtiquetaDe(int tamanoDelContenido) {
  return [
    0x49, 0x44, 0x33, // "ID3"
    0x03, 0x00, 0x00, // versión 2.3.0, sin banderas
    (tamanoDelContenido >> 21) & 0x7F,
    (tamanoDelContenido >> 14) & 0x7F,
    (tamanoDelContenido >> 7) & 0x7F,
    tamanoDelContenido & 0x7F,
    ...List<int>.filled(tamanoDelContenido, 0x00),
  ];
}

/// Cuántos bytes pide un encabezado `Range: bytes=0-N`.
int _bytesPedidos(String rango) {
  final hasta = int.parse(rango.split('-').last);
  return hasta + 1;
}

/// Un servidor de mentira que RESPETA el rango pedido, como hace R2.
///
/// Que lo respete importa: si devolviera el archivo entero siempre, el
/// test no distinguiría entre pedir 64 KB y pedir 512, que es
/// justamente lo que se quiere medir.
MockClient _servidorQueRespetaElRango(
  List<int> archivo,
  List<String> rangosPedidos,
) {
  return MockClient((pedido) async {
    final rango = pedido.headers['Range'] ?? '';
    rangosPedidos.add(rango);
    final pedidos = _bytesPedidos(rango);
    final hasta = pedidos < archivo.length ? pedidos : archivo.length;
    return http.Response.bytes(archivo.sublist(0, hasta), 206);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String carpeta;
  setUp(() async {
    carpeta = (await Directory.systemTemp.createTemp('cacocapp_datos')).path;
    PathProviderPlatform.instance = _CarpetaFalsa(carpeta);
  });

  group('cuántos datos se bajan de cada canción', () {
    test('una canción con etiqueta chica se baja de UNA sola vez', () async {
      // Una etiqueta sin carátula ocupa unos pocos kilobytes: entra
      // cómoda en el primer pedido y no hace falta ninguno más.
      final rangos = <String>[];
      final servicio = Id3CoverService.testable(
          _servidorQueRespetaElRango(_mp3ConEtiquetaDe(3000), rangos));

      await servicio.getEmbeddedCoverPath('https://ejemplo.test/a.mp3');

      expect(rangos.length, 1, reason: 'alcanzaba con un solo pedido');
      expect(_bytesPedidos(rangos.first), primerPedazoDeMp3);
      expect(_bytesPedidos(rangos.first), lessThan(524288),
          reason: 'tiene que pedir muchísimo menos que los 512 KB de antes');
    });

    test('una etiqueta grande se pide en dos, pero SOLO lo que mide', () async {
      // Con carátula grande el primer pedido no alcanza. El segundo
      // pide exactamente lo que la etiqueta dice medir, ni un byte más.
      const contenido = 200000;
      final rangos = <String>[];
      final servicio = Id3CoverService.testable(
          _servidorQueRespetaElRango(_mp3ConEtiquetaDe(contenido), rangos));

      await servicio.getEmbeddedCoverPath('https://ejemplo.test/b.mp3');

      expect(rangos.length, 2);
      expect(_bytesPedidos(rangos[0]), primerPedazoDeMp3);
      // 10 del encabezado más el contenido declarado.
      expect(_bytesPedidos(rangos[1]), contenido + 10);
    });

    test('un archivo SIN etiqueta al principio no dispara un segundo pedido',
        () async {
      // Los MP3 sin etiqueta al inicio existen. No hay nada que
      // calcular, así que no hay nada más que pedir.
      final rangos = <String>[];
      final servicio = Id3CoverService.testable(MockClient((pedido) async {
        rangos.add(pedido.headers['Range'] ?? '');
        return http.Response.bytes(
            [0xFF, 0xFB, 0x90, 0x00, ...List<int>.filled(500, 0)], 206);
      }));

      await servicio.getEmbeddedCoverPath('https://ejemplo.test/c.mp3');

      expect(rangos.length, 1);
    });

    test('si el segundo pedido falla, se usa lo que ya se había bajado',
        () async {
      // Puede pasar que se corte la conexión entre uno y otro. Tener
      // media etiqueta es mejor que no tener nada: quizá alcance para
      // el título aunque falte la carátula.
      final archivo = _mp3ConEtiquetaDe(200000);
      var pedidos = 0;
      final servicio = Id3CoverService.testable(MockClient((pedido) async {
        pedidos++;
        if (pedidos == 1) {
          // El primer pedazo, recortado como haría el servidor.
          return http.Response.bytes(
              archivo.sublist(0, primerPedazoDeMp3), 206);
        }
        return http.Response('se cayó', 500);
      }));

      // Lo que importa es que no reviente ni se quede colgado.
      await servicio.getEmbeddedCoverPath('https://ejemplo.test/d.mp3');
      expect(pedidos, 2);
    });

    test('LA CUENTA: 160 canciones sin carátula', () {
      // El caso real de esta app. No se mide con la red: se mide con
      // los números, que es lo único que hace falta.
      const canciones = 160;
      const antes = 524288 * canciones;
      const ahora = primerPedazoDeMp3 * canciones;

      expect(antes ~/ (1024 * 1024), 80, reason: 'antes: 80 MB');
      expect(ahora ~/ (1024 * 1024), 10, reason: 'ahora: 10 MB');
    });
  });
}
