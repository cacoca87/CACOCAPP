import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:CACOCAPP/services/jamendo_service.dart';

void main() {
  group('JamendoService', () {
    test('buscar() con texto vacío no pega a la red y devuelve []', () async {
      final client = MockClient((request) async {
        fail('No debería llamar a la red con una búsqueda vacía');
      });

      final servicio = JamendoService.testable(client);
      final resultado = await servicio.buscar('   ');

      expect(resultado, isEmpty);
    });

    test('buscar() arma Song a partir de la respuesta de Jamendo', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['search'], 'bossa nova');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'id': 123,
                'name': 'Canción de prueba',
                'artist_name': 'Artista de prueba',
                'album_name': 'Álbum de prueba',
                'audio': 'https://ejemplo.com/audio.mp3',
                'image': 'https://ejemplo.com/cover.jpg',
              }
            ]
          }),
          200,
        );
      });

      final servicio = JamendoService.testable(client);
      final resultado = await servicio.buscar('bossa nova');

      expect(resultado, hasLength(1));
      expect(resultado.first.id, 'jamendo_123');
      expect(resultado.first.title, 'Canción de prueba');
      expect(resultado.first.artist, 'Artista de prueba');
      expect(resultado.first.url, 'https://ejemplo.com/audio.mp3');
    });

    test('descarta resultados sin url de audio', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'results': [
              {'id': 1, 'name': 'Sin audio', 'audio': ''},
            ]
          }),
          200,
        );
      });

      final servicio = JamendoService.testable(client);
      final resultado = await servicio.buscar('algo');

      expect(resultado, isEmpty);
    });

    test('usa valores por defecto cuando faltan campos de metadata', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'results': [
              {'id': 5, 'audio': 'https://ejemplo.com/a.mp3'},
            ]
          }),
          200,
        );
      });

      final servicio = JamendoService.testable(client);
      final resultado = await servicio.buscar('algo');

      expect(resultado.single.title, 'Sin título');
      expect(resultado.single.artist, 'Artista independiente');
      expect(resultado.single.album, 'Jamendo');
    });

    test('lanza una excepción si Jamendo responde con error HTTP', () async {
      final client = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final servicio = JamendoService.testable(client);

      expect(() => servicio.buscar('algo'), throwsException);
    });

    test('buscarPorGenero() manda tags y order=popularity_total', () async {
      String? tagsEnviado;
      String? orderEnviado;

      final client = MockClient((request) async {
        tagsEnviado = request.url.queryParameters['tags'];
        orderEnviado = request.url.queryParameters['order'];
        return http.Response(jsonEncode({'results': []}), 200);
      });

      final servicio = JamendoService.testable(client);
      await servicio.buscarPorGenero('electronic');

      expect(tagsEnviado, 'electronic');
      expect(orderEnviado, 'popularity_total');
    });
  });
}
