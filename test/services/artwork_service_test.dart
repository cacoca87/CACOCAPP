import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CACOCAPP/services/artwork_service.dart';

String _respuestaConCaratula(String url) => jsonEncode({
      'results': [
        {'artworkUrl100': url}
      ]
    });

const _sinResultados = '{"results": []}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ArtworkService.getCoverUrl', () {
    test('pide una carátula grande, no la miniatura de 100x100', () async {
      final servicio = ArtworkService.testable(
        MockClient((_) async => http.Response(
            _respuestaConCaratula('https://itunes.test/a/100x100bb.jpg'), 200)),
      );
      expect(
        await servicio.getCoverUrl('Roxanne', 'The Police'),
        'https://itunes.test/a/600x600bb.jpg',
      );
    });

    test('una carátula encontrada sobrevive a reabrir la app', () async {
      final conRed = ArtworkService.testable(
        MockClient((_) async => http.Response(
            _respuestaConCaratula('https://itunes.test/b/600x600bb.jpg'), 200)),
      );
      await conRed.getCoverUrl('Cancion', 'Artista');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      var pidioRed = false;
      final sinRed = ArtworkService.testable(MockClient((_) async {
        pidioRed = true;
        return http.Response(_sinResultados, 200);
      }));
      expect(await sinRed.getCoverUrl('Cancion', 'Artista'),
          'https://itunes.test/b/600x600bb.jpg');
      expect(pidioRed, isFalse);
    });

    test('"iTunes no la tiene" SÍ se guarda: no tiene sentido volver a pedirla',
        () async {
      var llamadas = 0;
      final servicio = ArtworkService.testable(MockClient((_) async {
        llamadas++;
        return http.Response(_sinResultados, 200);
      }));
      await servicio.getCoverUrl('Rara', 'Nadie');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Sesión nueva: la respuesta negativa guardada evita el pedido.
      final otra = ArtworkService.testable(MockClient((_) async {
        llamadas++;
        return http.Response(_sinResultados, 200);
      }));
      expect(await otra.getCoverUrl('Rara', 'Nadie'), isNull);
      expect(llamadas, 1);
    });

    test('un fallo de red NO se guarda como "no tiene carátula"', () async {
      // Este era el fallo grave: abrir la app una sola vez sin internet
      // dejaba TODAS las canciones marcadas como "sin carátula" para
      // siempre, con el dibujito gris en cada fila.
      final sinRed = ArtworkService.testable(
        MockClient((_) async => throw const SocketException('sin red')),
      );
      expect(await sinRed.getCoverUrl('Roxanne', 'The Police'), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final conRed = ArtworkService.testable(
        MockClient((_) async => http.Response(
            _respuestaConCaratula('https://itunes.test/c/600x600bb.jpg'), 200)),
      );
      expect(await conRed.getCoverUrl('Roxanne', 'The Police'),
          'https://itunes.test/c/600x600bb.jpg');
    });

    test('un error del servidor tampoco se guarda como definitivo', () async {
      final caido = ArtworkService.testable(
        MockClient((_) async => http.Response('', 503)),
      );
      expect(await caido.getCoverUrl('Otra', 'Alguien'), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final sano = ArtworkService.testable(
        MockClient((_) async => http.Response(
            _respuestaConCaratula('https://itunes.test/d/600x600bb.jpg'), 200)),
      );
      expect(await sano.getCoverUrl('Otra', 'Alguien'),
          'https://itunes.test/d/600x600bb.jpg');
    });
  });
}
