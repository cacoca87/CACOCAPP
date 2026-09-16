import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CACOCAPP/models/song.dart';
import 'package:CACOCAPP/providers/playlist_provider.dart';

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

  group('PlaylistProvider: no perder canciones que no están en la biblioteca',
      () {
    test('un favorito sobrevive aunque la canción no esté en allSongs',
        () async {
      final deJamendo = _song('jamendo_1');

      final antes = PlaylistProvider();
      antes.toggleFavorite(deJamendo.id);
      await Future<void>.delayed(Duration.zero);

      // Al reabrir la app, la biblioteca del Drive no incluye las
      // canciones de Jamendo que no se descargaron.
      final despues = PlaylistProvider();
      await despues.loadFromPrefs([_song('drive_1')]);

      expect(despues.isFavorite(deJamendo.id), isTrue);
    });

    test('una canción de playlist no resuelta no se borra del disco', () async {
      final deJamendo = _song('jamendo_1');
      final deDrive = _song('drive_1');

      final antes = PlaylistProvider();
      final lista = antes.createPlaylist('Mezcla');
      antes.addSongToPlaylist(lista.id, deDrive);
      antes.addSongToPlaylist(lista.id, deJamendo);
      await Future<void>.delayed(Duration.zero);

      // Primera apertura sin la canción de Jamendo: no se puede mostrar,
      // pero tampoco debe desaparecer. Cualquier acción posterior vuelve
      // a guardar en disco, que era donde se perdía para siempre.
      final sinJamendo = PlaylistProvider();
      await sinJamendo.loadFromPrefs([deDrive]);
      expect(sinJamendo.playlists.single.songs.map((s) => s.id), ['drive_1']);
      sinJamendo.toggleFavorite('cualquiera');
      await Future<void>.delayed(Duration.zero);

      // Segunda apertura, ya con la canción disponible: tiene que volver.
      final conJamendo = PlaylistProvider();
      await conJamendo.loadFromPrefs([deDrive, deJamendo]);
      expect(
        conJamendo.playlists.single.songs.map((s) => s.id),
        containsAll(['drive_1', 'jamendo_1']),
      );
    });

    test('volver a agregar una canción no resuelta no la duplica', () async {
      final deJamendo = _song('jamendo_1');
      final deDrive = _song('drive_1');

      final antes = PlaylistProvider();
      final lista = antes.createPlaylist('Mezcla');
      antes.addSongToPlaylist(lista.id, deJamendo);
      await Future<void>.delayed(Duration.zero);

      final despues = PlaylistProvider();
      await despues.loadFromPrefs([deDrive]);
      despues.addSongToPlaylist(despues.playlists.single.id, deJamendo);
      await Future<void>.delayed(Duration.zero);

      final final_ = PlaylistProvider();
      await final_.loadFromPrefs([deDrive, deJamendo]);
      expect(final_.playlists.single.songs.map((s) => s.id).toList(),
          ['jamendo_1']);
    });
  });
}
