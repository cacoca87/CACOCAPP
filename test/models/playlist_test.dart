import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/models/playlist.dart';
import 'package:CACOCAPP/models/song.dart';

Song _cancion(String id) => Song(
      id: id,
      title: 'Canción $id',
      artist: 'Artista',
      album: 'Álbum',
      url: 'https://ejemplo.com/$id.mp3',
      coverUrl: '',
    );

void main() {
  group('Playlist', () {
    test('arranca vacía cuando no se pasan canciones', () {
      final playlist = Playlist(id: 'p1', name: 'Mi playlist');
      expect(playlist.songs, isEmpty);
    });

    test('addSong agrega la canción', () {
      final playlist = Playlist(id: 'p1', name: 'Mi playlist');
      playlist.addSong(_cancion('1'));
      expect(playlist.songs.map((s) => s.id), ['1']);
    });

    test('addSong no duplica una canción ya agregada (mismo id)', () {
      final playlist = Playlist(id: 'p1', name: 'Mi playlist');
      playlist.addSong(_cancion('1'));
      playlist.addSong(_cancion('1'));
      expect(playlist.songs.length, 1);
    });

    test('removeSong saca la canción por id', () {
      final playlist = Playlist(
        id: 'p1',
        name: 'Mi playlist',
        songs: [_cancion('1'), _cancion('2')],
      );

      playlist.removeSong('1');

      expect(playlist.songs.map((s) => s.id), ['2']);
    });

    test('removeSong con un id que no existe no rompe nada', () {
      final playlist = Playlist(
        id: 'p1',
        name: 'Mi playlist',
        songs: [_cancion('1')],
      );

      playlist.removeSong('no-existe');

      expect(playlist.songs.length, 1);
    });
  });
}
