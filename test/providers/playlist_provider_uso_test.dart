import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CACOCAPP/models/song.dart';
import 'package:CACOCAPP/providers/playlist_provider.dart';

/// Las playlists y los favoritos son **lo único que la app no puede
/// volver a conseguir si se pierde**.
///
/// Una canción borrada se vuelve a bajar. Una playlist de cuarenta
/// temas armada a mano, no. Por eso esto merece más tests que cualquier
/// otra cosa, y hasta ahora tenía tres --todos sobre un caso raro--.
///
/// El archivo hermano (`playlist_provider_test.dart`) cubre ese caso
/// raro: canciones guardadas en una playlist que al abrir la app no se
/// pueden reconstruir. Acá va lo de todos los días.

Song _song(String id) => Song(
      id: id,
      title: 'Titulo $id',
      artist: 'Artista',
      album: 'Album',
      url: 'https://ejemplo.test/$id.mp3',
      coverUrl: '',
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('lo que hace la persona todos los días', () {
    test('crear una playlist y ponerle canciones', () {
      final p = PlaylistProvider();
      final lista = p.createPlaylist('Rock');

      p.addSongToPlaylist(lista.id, _song('a'));
      p.addSongToPlaylist(lista.id, _song('b'));

      expect(p.playlists.length, 1);
      expect(p.playlists.first.name, 'Rock');
      expect(p.playlists.first.songs.map((s) => s.id), ['a', 'b']);
    });

    test('la misma canción dos veces NO se duplica', () {
      final p = PlaylistProvider();
      final lista = p.createPlaylist('Rock');

      p.addSongToPlaylist(lista.id, _song('a'));
      p.addSongToPlaylist(lista.id, _song('a'));

      expect(p.playlists.first.songs.length, 1);
    });

    test('dos playlists creadas en el mismo instante no comparten id', () {
      // Con el id sacado solo de la hora en milisegundos, dos creadas
      // muy seguido tenían el mismo. Como se buscan por id, una quedaba
      // inalcanzable o se editaba la otra sin querer.
      final p = PlaylistProvider();
      final ids = {
        for (var i = 0; i < 50; i++) p.createPlaylist('Lista $i').id
      };
      expect(ids.length, 50);
    });

    test('quitar una canción no toca las demás', () {
      final p = PlaylistProvider();
      final lista = p.createPlaylist('Rock');
      p.addSongToPlaylist(lista.id, _song('a'));
      p.addSongToPlaylist(lista.id, _song('b'));
      p.addSongToPlaylist(lista.id, _song('c'));

      p.removeSongFromPlaylist(lista.id, 'b');

      expect(p.playlists.first.songs.map((s) => s.id), ['a', 'c']);
    });

    test('renombrar conserva las canciones', () {
      final p = PlaylistProvider();
      final lista = p.createPlaylist('Rock');
      p.addSongToPlaylist(lista.id, _song('a'));

      p.renamePlaylist(lista.id, 'Rock nacional');

      expect(p.playlists.first.name, 'Rock nacional');
      expect(p.playlists.first.songs.length, 1,
          reason: 'renombrar no puede vaciar la playlist');
    });

    test('borrar una playlist no toca las otras', () {
      final p = PlaylistProvider();
      final una = p.createPlaylist('Una');
      final otra = p.createPlaylist('Otra');
      p.addSongToPlaylist(otra.id, _song('a'));

      p.deletePlaylist(una.id);

      expect(p.playlists.length, 1);
      expect(p.playlists.first.name, 'Otra');
      expect(p.playlists.first.songs.length, 1);
    });

    test('pedirle algo a una playlist que no existe no revienta', () {
      // Pasa de verdad: se borra desde el menú lateral mientras el menú
      // de opciones de una canción sigue abierto apuntando a ella.
      final p = PlaylistProvider();
      expect(() {
        p.addSongToPlaylist('no-existe', _song('a'));
        p.removeSongFromPlaylist('no-existe', 'a');
        p.renamePlaylist('no-existe', 'Nada');
        p.deletePlaylist('no-existe');
      }, returnsNormally);
      expect(p.playlists, isEmpty);
    });

    test('marcar y desmarcar un favorito', () {
      final p = PlaylistProvider();
      expect(p.isFavorite('a'), isFalse);

      p.toggleFavorite('a');
      expect(p.isFavorite('a'), isTrue);

      p.toggleFavorite('a');
      expect(p.isFavorite('a'), isFalse);
    });

    test('la lista de playlists que se entrega no se puede modificar', () {
      // Si se pudiera, cualquier pantalla podría agregarle o sacarle
      // cosas por afuera y el provider nunca se enteraría: no avisaría
      // a nadie ni lo guardaría en el disco.
      final p = PlaylistProvider();
      p.createPlaylist('Rock');
      expect(() => p.playlists.clear(), throwsUnsupportedError);
    });

    test('avisa a las pantallas en cada cambio', () {
      // Sin el aviso, la barra lateral no se entera de que hay una
      // playlist nueva hasta que algo más la haga redibujarse.
      final p = PlaylistProvider();
      var avisos = 0;
      p.addListener(() => avisos++);

      final lista = p.createPlaylist('Rock');
      p.addSongToPlaylist(lista.id, _song('a'));
      p.removeSongFromPlaylist(lista.id, 'a');
      p.renamePlaylist(lista.id, 'Otro');
      p.toggleFavorite('a');
      p.deletePlaylist(lista.id);

      expect(avisos, 6);
    });
  });

  group('todo sigue ahí al reabrir la app', () {
    test('las playlists, su nombre y sus canciones vuelven', () async {
      final primera = PlaylistProvider();
      final lista = primera.createPlaylist('Rock nacional');
      primera.addSongToPlaylist(lista.id, _song('a'));
      primera.addSongToPlaylist(lista.id, _song('b'));
      // Lo guardado se escribe sin esperar: hay que darle un instante.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final segunda = PlaylistProvider();
      await segunda.loadFromPrefs([_song('a'), _song('b')]);

      expect(segunda.playlists.length, 1);
      expect(segunda.playlists.first.name, 'Rock nacional');
      expect(segunda.playlists.first.songs.map((s) => s.id), ['a', 'b']);
    });

    test('los favoritos vuelven', () async {
      final primera = PlaylistProvider();
      primera.toggleFavorite('a');
      primera.toggleFavorite('b');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final segunda = PlaylistProvider();
      await segunda.loadFromPrefs([_song('a')]);

      expect(segunda.isFavorite('a'), isTrue);
      // Y este sobrevive aunque la canción no esté en la biblioteca: un
      // favorito es un id marcado, no hace falta tener la canción a
      // mano para recordar que te gustaba.
      expect(segunda.isFavorite('b'), isTrue);
    });

    test('una playlist borrada no vuelve', () async {
      final primera = PlaylistProvider();
      final lista = primera.createPlaylist('Rock');
      primera.addSongToPlaylist(lista.id, _song('a'));
      primera.deletePlaylist(lista.id);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final segunda = PlaylistProvider();
      await segunda.loadFromPrefs([_song('a')]);

      expect(segunda.playlists, isEmpty);
    });

    test('abrir la app sin nada guardado no rompe nada', () async {
      final p = PlaylistProvider();
      await p.loadFromPrefs([_song('a')]);
      expect(p.playlists, isEmpty);
      expect(p.isFavorite('a'), isFalse);
    });

    test('lo guardado en un formato roto no tira la app abajo', () async {
      // Puede pasar por una actualización a medias, o porque el archivo
      // quedó cortado. Perder las playlists es feo; que la app no
      // arranque es peor.
      SharedPreferences.setMockInitialValues({
        'cacocapp_playlists_v1': 'esto no es json',
      });
      final p = PlaylistProvider();
      await p.loadFromPrefs([_song('a')]);
      expect(p.playlists, isEmpty);
    });
  });
}
