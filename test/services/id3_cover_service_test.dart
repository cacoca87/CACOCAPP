import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:CACOCAPP/services/id3_cover_service.dart';

/// Reemplaza la carpeta temporal real de Android por una de verdad en
/// el disco de la máquina donde corren los tests. Hace falta porque lo
/// que se está probando es justamente QUÉ archivos deja escritos el
/// servicio: sin esto, las escrituras fallarían en silencio y el test
/// pasaría sin comprobar nada.
class _CarpetaFalsa extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _CarpetaFalsa(this.raiz);
  final String raiz;

  @override
  Future<String?> getTemporaryPath() async => raiz;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory raiz;
  late Directory carpetaDeCache;

  setUp(() async {
    raiz = await Directory.systemTemp.createTemp('cacocapp_id3_test');
    PathProviderPlatform.instance = _CarpetaFalsa(raiz.path);
    carpetaDeCache = Directory('${raiz.path}/id3_covers');
  });

  tearDown(() async {
    if (await raiz.exists()) await raiz.delete(recursive: true);
  });

  const url = 'https://ejemplo.test/Roxanne.mp3';
  // El nombre que el servicio le da a sus archivos sale del último
  // segmento de la URL.
  const clave = 'Roxanne.mp3';

  Future<bool> existeMarca(String extension) =>
      File('${carpetaDeCache.path}/$clave.$extension').exists();

  /// Las marcas se escriben sin esperar (a propósito: no tienen que
  /// frenar la pantalla), así que hay que darles un instante antes de
  /// mirar el disco.
  Future<void> esperarEscrituras() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  group('Id3CoverService: no confundir "no hay" con "no pude leerlo"', () {
    test('sin internet NO deja la canción marcada como "sin carátula"',
        () async {
      // Este era el fallo más grave de toda la app: abrirla una sola vez
      // con mala señal dejaba cientos de canciones marcadas en el disco
      // como "sin carátula" y "Artista Desconocido" PARA SIEMPRE,
      // aunque el MP3 sí trajera esos datos.
      final servicio = Id3CoverService.testable(
        MockClient((_) async => throw const SocketException('sin red')),
      );

      expect(await servicio.getEmbeddedCover(url), isNull);
      await esperarEscrituras();
      expect(await existeMarca('nocover'), isFalse,
          reason: 'un fallo de red no puede quedar escrito como definitivo');
    });

    test('un error del servidor tampoco deja la marca', () async {
      final servicio = Id3CoverService.testable(
        MockClient((_) async => http.Response('', 503)),
      );

      expect(await servicio.getEmbeddedCover(url), isNull);
      await esperarEscrituras();
      expect(await existeMarca('nocover'), isFalse);
    });

    test('un archivo que SÍ se pudo leer y no trae tags sí deja la marca',
        () async {
      // Acá la respuesta llegó entera: que no tenga carátula es un dato
      // definitivo y vale la pena anotarlo para no volver a bajar 512 KB
      // cada vez.
      final servicio = Id3CoverService.testable(
        MockClient((_) async => http.Response.bytes(
              List<int>.filled(2048, 0),
              206,
            )),
      );

      expect(await servicio.getEmbeddedCover(url), isNull);
      await esperarEscrituras();
      expect(await existeMarca('nocover'), isTrue);
    });

    test('lo mismo para el álbum y el artista', () async {
      final sinRed = Id3CoverService.testable(
        MockClient((_) async => throw const SocketException('sin red')),
      );
      expect(await sinRed.getEmbeddedAlbum(url), isNull);
      expect(await sinRed.getEmbeddedArtist(url), isNull);
      await esperarEscrituras();
      expect(await existeMarca('noalbum'), isFalse);
      expect(await existeMarca('noartist'), isFalse);

      final conRed = Id3CoverService.testable(
        MockClient(
            (_) async => http.Response.bytes(List<int>.filled(2048, 0), 206)),
      );
      expect(await conRed.getEmbeddedAlbum(url), isNull);
      await esperarEscrituras();
      expect(await existeMarca('noalbum'), isTrue);
    });

    test('una vez marcada, no vuelve a pedirla por red', () async {
      var llamadas = 0;
      final primera = Id3CoverService.testable(MockClient((_) async {
        llamadas++;
        return http.Response.bytes(List<int>.filled(2048, 0), 206);
      }));
      await primera.getEmbeddedCover(url);
      await esperarEscrituras();
      expect(llamadas, 1);

      // Sesión nueva: la marca en disco evita el pedido.
      final segunda = Id3CoverService.testable(MockClient((_) async {
        llamadas++;
        return http.Response.bytes(List<int>.filled(2048, 0), 206);
      }));
      expect(await segunda.getEmbeddedCover(url), isNull);
      expect(llamadas, 1);
    });
  });
}
