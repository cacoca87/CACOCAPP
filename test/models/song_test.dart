import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/models/song.dart';

void main() {
  group('Song', () {
    test('playlists arranca vacía cuando no se especifica', () {
      final cancion = Song(
        id: '1',
        title: 'Título',
        artist: 'Artista',
        album: 'Álbum',
        url: 'https://ejemplo.com/cancion.mp3',
        coverUrl: 'https://ejemplo.com/cover.jpg',
      );

      expect(cancion.playlists, isEmpty);
    });

    test('respeta la lista de playlists provista', () {
      final cancion = Song(
        id: '1',
        title: 'Título',
        artist: 'Artista',
        album: 'Álbum',
        url: 'https://ejemplo.com/cancion.mp3',
        coverUrl: 'https://ejemplo.com/cover.jpg',
        playlists: const ['favoritas'],
      );

      expect(cancion.playlists, ['favoritas']);
    });

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
  });
}
