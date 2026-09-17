import 'dart:io';
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

    test('un "no hay letra" por falta de red NO se guarda en el disco',
        () async {
      // Este era el fallo: una sola consulta hecha sin internet dejaba
      // la canción marcada como "sin letra" para siempre, incluso con
      // la conexión ya funcionando.
      final sinRed = LyricsService.testable(
        MockClient((_) async => throw const SocketException('sin red')),
      );
      expect(
        (await sinRed.getLyrics(
                title: 'Roxanne', artist: 'The Police', urlCancion: ''))
            .hayAlgo,
        isFalse,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Sesión nueva (caché de memoria vacía) y con la red andando: la
      // letra tiene que aparecer.
      final conRed = LyricsService.testable(MockClient((request) async {
        if (request.url.host != 'lrclib.net') {
          return http.Response('Not Found', 404);
        }
        return http.Response(
          jsonEncode([
            {'syncedLyrics': null, 'plainLyrics': 'Roxanne...'}
          ]),
          200,
        );
      }));
      final letra = await conRed.getLyrics(
          title: 'Roxanne', artist: 'The Police', urlCancion: '');
      expect(letra.textoPlano, 'Roxanne...');
    });

    test('una letra encontrada SÍ se guarda y sobrevive a reabrir la app',
        () async {
      final conRed = LyricsService.testable(MockClient((request) async {
        if (request.url.host != 'lrclib.net') {
          return http.Response('Not Found', 404);
        }
        return http.Response(
          jsonEncode([
            {'syncedLyrics': null, 'plainLyrics': 'Guardada'}
          ]),
          200,
        );
      }));
      await conRed.getLyrics(
          title: 'Cancion', artist: 'Artista', urlCancion: '');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Sesión nueva y sin red: tiene que salir del disco igual.
      var pidioRed = false;
      final sinRed = LyricsService.testable(MockClient((_) async {
        pidioRed = true;
        return http.Response('Not Found', 404);
      }));
      final letra = await sinRed.getLyrics(
          title: 'Cancion', artist: 'Artista', urlCancion: '');
      expect(letra.textoPlano, 'Guardada');
      expect(pidioRed, isFalse);
    });

    test('una letra guardada con la regla vieja se descarta', () async {
      // Sin esto la corrección no se nota: lo guardado se lee ANTES de
      // buscar nada, así que "Amén" seguiría mostrando la letra en
      // inglés de otra canción para siempre.
      SharedPreferences.setMockInitialValues({
        'lyrics_cache_v1_roxanne|the police':
            '{"plano":"letra vieja equivocada","lineas":null}',
      });

      final servicio = LyricsService.testable(MockClient((request) async {
        if (request.url.host != 'lrclib.net') {
          return http.Response('Not Found', 404);
        }
        return http.Response(
          jsonEncode([
            {'syncedLyrics': null, 'plainLyrics': 'la letra correcta'}
          ]),
          200,
        );
      }));

      final letra = await servicio.getLyrics(
          title: 'Roxanne', artist: 'The Police', urlCancion: '');
      expect(letra.textoPlano, 'la letra correcta');

      // Y además se borra, para no dejarla ocupando lugar.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('lyrics_cache_v1_roxanne|the police'), isFalse);
    });

    test('una letra guardada con un renglón roto NO se pierde entera',
        () async {
      // Lo guardado en el celular se lee ANTES de buscar nada. Si un
      // solo renglón venía con otra forma --sin texto, o con el tiempo
      // escrito como palabra-- el lector saltaba con un error de tipo
      // que se atrapaba más arriba, y el resultado era que la canción
      // se quedaba SIN LETRA aunque las otras cuarenta líneas
      // estuvieran perfectas.
      SharedPreferences.setMockInitialValues({
        'lyrics_cache_v3_roxanne|the police': jsonEncode({
          'plano': null,
          'lineas': [
            {'ms': 1000, 'texto': 'primera linea'},
            {'ms': 'rota', 'texto': 'esta no sirve'},
            {'ms': 3000},
            'ni siquiera es un renglon',
            {'ms': 4000, 'texto': 'ultima linea'},
          ],
        }),
      });

      final servicio = LyricsService.testable(
        MockClient((_) async => http.Response('[]', 200)),
      );
      final letra = await servicio.getLyrics(
          title: 'Roxanne', artist: 'The Police', urlCancion: '');

      expect(letra.estaSincronizada, isTrue,
          reason: 'las líneas buenas tienen que sobrevivir');
      expect(
          letra.lineas!.map((l) => l.texto), ['primera linea', 'ultima linea']);
    });
  });
}
