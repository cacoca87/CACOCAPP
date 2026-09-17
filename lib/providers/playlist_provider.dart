import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../utils/app_logger.dart';

class PlaylistProvider extends ChangeNotifier {
  final List<Playlist> _playlists = [];
  final Set<String> _favoriteIds = {};

  // Canciones que están guardadas en una playlist pero que no se
  // pudieron reconstruir al abrir la app, porque no aparecen en la
  // lista con la que se llamó a [loadFromPrefs] (típicamente una
  // canción de Jamendo que agregaste sin descargar: no está ni en la
  // biblioteca del Drive ni entre las descargas).
  //
  // Antes esos ids simplemente se descartaban, y el problema no era que
  // no se mostraran -- era que el siguiente `_persist()`, disparado por
  // cualquier cosa que hicieras después (marcar un favorito, crear una
  // playlist), volvía a escribir la lista ya recortada y los borraba
  // del disco PARA SIEMPRE. Guardarlos acá los mantiene en el archivo
  // hasta que la canción se pueda resolver de nuevo.
  final Map<String, List<String>> _idsSinResolver = {};

  List<Playlist> get playlists => List.unmodifiable(_playlists);

  bool isFavorite(String songId) => _favoriteIds.contains(songId);

  static const _kPlaylistsKey = 'cacocapp_playlists_v1';
  static const _kFavoritesKey = 'cacocapp_favorites_v1';

  void toggleFavorite(String songId) {
    if (_favoriteIds.contains(songId)) {
      _favoriteIds.remove(songId);
    } else {
      _favoriteIds.add(songId);
    }
    notifyListeners();
    _persist();
  }

  // Contador para el id de las playlists nuevas. Solo con la hora en
  // milisegundos, dos playlists creadas dentro del mismo milisegundo
  // compartian id, y como las playlists se buscan por id una de las dos
  // quedaba inalcanzable (o se editaba la otra sin querer).
  int _contadorDeIds = 0;

  Playlist createPlaylist(String name) {
    final playlist = Playlist(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_contadorDeIds++}',
      name: name,
    );
    _playlists.add(playlist);
    notifyListeners();
    _persist();
    return playlist;
  }

  void deletePlaylist(String playlistId) {
    _playlists.removeWhere((p) => p.id == playlistId);
    _idsSinResolver.remove(playlistId);
    notifyListeners();
    _persist();
  }

  void renamePlaylist(String playlistId, String nuevoNombre) {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;
    _playlists[index].name = nuevoNombre;
    notifyListeners();
    _persist();
  }

  void addSongToPlaylist(String playlistId, Song song) {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;
    _playlists[index].addSong(song);
    // Si esta canción era una de las que no se habían podido resolver,
    // ya dejó de serlo -- si no se saca de ahí, `_persist()` escribiría
    // su id dos veces y al reabrir la app aparecería duplicada.
    _idsSinResolver[playlistId]?.remove(song.id);
    notifyListeners();
    _persist();
  }

  void removeSongFromPlaylist(String playlistId, String songId) {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;
    _playlists[index].removeSong(songId);
    _idsSinResolver[playlistId]?.remove(songId);
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = _playlists
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'songIds': [
                  ...p.songs.map((s) => s.id),
                  ...?_idsSinResolver[p.id],
                ],
              })
          .toList();
      await prefs.setString(_kPlaylistsKey, jsonEncode(playlistsJson));
      await prefs.setStringList(_kFavoritesKey, _favoriteIds.toList());
    } catch (e) {
      AppLogger.e('No se pudieron guardar playlists/favoritos', error: e);
    }
  }

  Future<void> loadFromPrefs(List<Song> allSongs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songById = {for (final s in allSongs) s.id: s};

      final favIds = prefs.getStringList(_kFavoritesKey);
      if (favIds != null) {
        // Se guardan los ids sin filtrar por los que estén en
        // `allSongs`. Un favorito es solo un id marcado -- no hace falta
        // tener la canción a mano para recordar que te gustaba, y
        // filtrarlos acá hacía que se perdieran solos (ver la nota de
        // `_idsSinResolver`).
        _favoriteIds
          ..clear()
          ..addAll(favIds);
      }

      final playlistsRaw = prefs.getString(_kPlaylistsKey);
      if (playlistsRaw != null) {
        final decoded = jsonDecode(playlistsRaw) as List;
        _playlists.clear();
        _idsSinResolver.clear();
        for (final item in decoded) {
          final map = item as Map<String, dynamic>;
          final songIds = (map['songIds'] as List).cast<String>();
          final id = map['id'] as String;
          final songs =
              songIds.map((sid) => songById[sid]).whereType<Song>().toList();
          final sinResolver =
              songIds.where((sid) => !songById.containsKey(sid)).toList();
          if (sinResolver.isNotEmpty) _idsSinResolver[id] = sinResolver;
          _playlists.add(Playlist(
            id: id,
            name: map['name'] as String,
            songs: songs,
          ));
        }
      }
      notifyListeners();
    } catch (e) {
      AppLogger.e('No se pudieron restaurar playlists/favoritos', error: e);
    }
  }
}
