import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/services/musica_local_service.dart';

void main() {
  group('cancionDesdeElCelular', () {
    test('usa los datos que trae el archivo', () {
      final cancion = cancionDesdeElCelular(
        id: 42,
        titulo: 'Te Quiero',
        artista: 'Amén',
        album: 'Libre',
        ruta: '/storage/emulated/0/Music/amen.mp3',
      );

      expect(cancion.title, 'Te Quiero');
      expect(cancion.artist, 'Amén');
      expect(cancion.album, 'Libre');
    });

    test('el id no puede chocar con los de las otras fuentes', () {
      // En la app conviven canciones del servidor (`r2_...`), de Jamendo
      // (`jamendo_...`) y ahora del celular. Los ids son la forma de
      // reconocer una canción en favoritos, playlists e historial: dos
      // canciones distintas con el mismo id se pisarían entre sí.
      expect(
        cancionDesdeElCelular(
                id: 42, titulo: 'x', artista: '', album: '', ruta: '/a.mp3')
            .id,
        'local_42',
      );
    });

    test('se reproduce como archivo local, igual que una descarga', () {
      // Es lo que hace que funcione sin escribir nada nuevo: el
      // reproductor y el lector de carátulas ya saben tratar con
      // `file://`.
      final cancion = cancionDesdeElCelular(
        id: 1,
        titulo: 'x',
        artista: '',
        album: '',
        ruta: '/storage/emulated/0/Music/tema.mp3',
      );

      expect(cancion.url, startsWith('file://'));
      expect(cancion.url, endsWith('tema.mp3'));
    });

    test('un archivo sin título muestra el nombre del archivo', () {
      // Medio de los MP3 que andan dando vueltas no tienen los datos
      // puestos. Mostrar el nombre del archivo es lo que hace cualquier
      // reproductor, y es mucho mejor que un "Sin título" en una fila
      // que la persona sí reconoce.
      final cancion = cancionDesdeElCelular(
        id: 1,
        titulo: '',
        artista: '',
        album: '',
        ruta: '/storage/emulated/0/Music/Amén - Te Quiero.mp3',
      );

      expect(cancion.title, 'Amén - Te Quiero');
    });

    test('"<unknown>" no se muestra tal cual', () {
      // Es literalmente lo que devuelve Android cuando el archivo no
      // dice quién lo toca. Dejarlo pasar pondría "<unknown>" en medio
      // de la lista, al lado de artistas de verdad.
      final cancion = cancionDesdeElCelular(
        id: 1,
        titulo: 'Tema',
        artista: '<unknown>',
        album: '<unknown>',
        ruta: '/a.mp3',
      );

      expect(cancion.artist, 'Artista Desconocido');
      expect(cancion.album, '');
    });

    test('los espacios de más no cuentan como datos', () {
      final cancion = cancionDesdeElCelular(
        id: 1,
        titulo: '   ',
        artista: '  Queen  ',
        album: '  ',
        ruta: '/storage/emulated/0/Music/bohemian.mp3',
      );

      expect(cancion.title, 'bohemian');
      expect(cancion.artist, 'Queen');
      expect(cancion.album, '');
    });
  });
}
