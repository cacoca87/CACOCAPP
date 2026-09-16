import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/models/song.dart';

void main() {
  group('Song', () {
    test('album es mutable (se actualiza cuando llega el tag ID3 real)', () {
      final cancion = Song(
        id: '1',
        title: 'Título',
        artist: 'Artista',
        album: 'Desconocido',
        url: 'https://ejemplo.com/cancion.mp3',
        coverUrl: '',
      );

      cancion.album = 'Álbum real';

      expect(cancion.album, 'Álbum real');
    });

    test(
      'artist es mutable (se actualiza cuando llega el tag ID3 real -- '
      'regresión: "Runnin\' Down A Dream.mp3" quedaba como "Artista Desconocido" para siempre)',
      () {
        final cancion = Song(
          id: '1',
          title: 'Runnin\' Down A Dream',
          artist: 'Artista Desconocido',
          album: '',
          url: 'https://ejemplo.com/cancion.mp3',
          coverUrl: '',
        );

        cancion.artist = 'Tom Petty';

        expect(cancion.artist, 'Tom Petty');
      },
    );
  });
}
