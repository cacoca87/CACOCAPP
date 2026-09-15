import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CACOCAPP/services/lyrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Sin esto, getLyrics() intenta llegar a SharedPreferences real
    // (un plugin nativo) apenas arranca, y el test cuelga/falla.
    SharedPreferences.setMockInitialValues({});
  });

  group('LyricsService.getLyrics', () {
    test(
        'encuentra letra sincronizada en el primer intento (título+artista tal cual)',
        () async {
      final client = MockClient((request) async {
        if (request.url.host == 'lrclib.net') {
          expect(request.url.queryParameters['track_name'], 'Roxanne');
          expect(request.url.queryParameters['artist_name'], 'The Police');
          return http.Response(
            jsonEncode([
              {
                'syncedLyrics':
                    '[00:01.00]Roxanne\n[00:05.00]You dont have to put on the red light',
                'plainLyrics': 'Roxanne\nYou dont have to put on the red light',
              }
            ]),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = LyricsService.testable(client);
      final letra = await service.getLyrics(
          title: 'Roxanne', artist: 'The Police', urlCancion: '');

      expect(letra.estaSincronizada, isTrue);
      expect(letra.lineas!.first.texto, 'Roxanne');
    });

    test(
      'regresión (CAMBIOS.md sección 13): si falla con el "artista" (canal de YouTube), '
      'reintenta con el artista real extraído del título "Artista - Canción"',
      () async {
        var intentosConCanalComoArtista = 0;

        final client = MockClient((request) async {
          if (request.url.host != 'lrclib.net') {
            return http.Response('Not Found', 404);
          }

          final artista = request.url.queryParameters['artist_name'];
          if (artista == 'Dj Montro Live') {
            // El "artista" real que llega es el nombre del CANAL de
            // YouTube, no el artista real -- esto no debe encontrar nada.
            intentosConCanalComoArtista++;
            return http.Response(jsonEncode([]), 200);
          }
          if (artista == 'Los Rodriguez') {
            // El artista real, extraído del propio título del video --
            // acá sí tiene que encontrar la letra.
            return http.Response(
              jsonEncode([
                {
                  'syncedLyrics': null,
                  'plainLyrics': 'Letra real de Los Rodriguez'
                }
              ]),
              200,
            );
          }
          return http.Response(jsonEncode([]), 200);
        });

        final service = LyricsService.testable(client);
        final letra = await service.getLyrics(
          title: 'Los Rodriguez - Sin Documentos',
          artist: 'Dj Montro Live',
          urlCancion: '',
        );

        expect(intentosConCanalComoArtista, 1);
        expect(letra.hayAlgo, isTrue);
        expect(letra.textoPlano, 'Letra real de Los Rodriguez');
      },
    );

    test('si no hay letra sincronizada pero sí texto plano, usa el texto plano',
        () async {
      final client = MockClient((request) async {
        if (request.url.host == 'lrclib.net') {
          return http.Response(
            jsonEncode([
              {'syncedLyrics': null, 'plainLyrics': 'Solo texto plano'}
            ]),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = LyricsService.testable(client);
      final letra = await service.getLyrics(
          title: 'Cancion', artist: 'Artista', urlCancion: '');

      expect(letra.estaSincronizada, isFalse);
      expect(letra.textoPlano, 'Solo texto plano');
    });

    test('devuelve Lyrics.vacia si ninguna fuente encuentra nada', () async {
      final client =
          MockClient((request) async => http.Response('Not Found', 404));

      final service = LyricsService.testable(client);
      final letra = await service.getLyrics(
          title: 'Cancion Inexistente', artist: 'Nadie', urlCancion: '');

      expect(letra.hayAlgo, isFalse);
    });
  });
}
