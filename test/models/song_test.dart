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

    test(
      'title es mutable (se corrige con el tag ID3 real -- regresión: '
      'tres temas del disco "Libre" llegaban los tres llamados "Amén", '
      'que es la banda)',
      () {
        // El caso real y comprobado: los archivos se llamaban
        // "Amén - Te Quiero.mp3", y como "Amén" no estaba en la lista
        // de artistas que van primero, la app tomaba esa parte como el
        // título. Resultado: tres canciones distintas mostradas con el
        // mismo nombre, y la letra no aparecía nunca porque se buscaba
        // una canción que no existe.
        //
        // Los otros dos campos mutables ya tenían su test; este no,
        // siendo que es el que más se vio en pantalla.
        final cancion = Song(
          id: '1',
          title: 'Amén',
          artist: 'Amén',
          album: 'Libre',
          url: 'https://ejemplo.com/Am%C3%A9n%20-%20Te%20Quiero.mp3',
          coverUrl: '',
        );

        cancion.title = 'Te Quiero';

        expect(cancion.title, 'Te Quiero');
      },
    );
  });
}
