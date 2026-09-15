import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import '../models/song.dart';

class PlaylistProvider extends ChangeNotifier {
  final List<Playlist> _playlists = [];
  final Set<String> _favoriteIds = {};

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  Set<String> get favoriteIds => _favoriteIds;

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

  Playlist createPlaylist(String name) {
    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    _playlists.add(playlist);
    notifyListeners();
    _persist();
    return playlist;
  }

  void deletePlaylist(String playlistId) {
    _playlists.removeWhere((p) => p.id == playlistId);
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
    notifyListeners();
    _persist();
  }

  void removeSongFromPlaylist(String playlistId, String songId) {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;
    _playlists[index].removeSong(songId);
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
                'songIds': p.songs.map((s) => s.id).toList(),
              })
          .toList();
      await prefs.setString(_kPlaylistsKey, jsonEncode(playlistsJson));
      await prefs.setStringList(_kFavoritesKey, _favoriteIds.toList());
    } catch (e) {
      debugPrint('No se pudieron guardar playlists/favoritos: $e');
    }
  }

  Future<void> loadFromPrefs(List<Song> allSongs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songById = {for (final s in allSongs) s.id: s};

      final favIds = prefs.getStringList(_kFavoritesKey);
      if (favIds != null) {
        _favoriteIds
          ..clear()
          ..addAll(favIds.where(songById.containsKey));
      }

      final playlistsRaw = prefs.getString(_kPlaylistsKey);
      if (playlistsRaw != null) {
        final decoded = jsonDecode(playlistsRaw) as List;
        _playlists.clear();
        for (final item in decoded) {
          final map = item as Map<String, dynamic>;
          final songIds = (map['songIds'] as List).cast<String>();
          final songs =
              songIds.map((id) => songById[id]).whereType<Song>().toList();
          _playlists.add(Playlist(
            id: map['id'] as String,
            name: map['name'] as String,
            songs: songs,
          ));
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('No se pudieron restaurar playlists/favoritos: $e');
    }
  }
}
