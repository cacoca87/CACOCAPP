import 'song.dart';

class Playlist {
  final String id;
  String name;
  final List<Song> songs;

  Playlist({
    required this.id,
    required this.name,
    List<Song>? songs,
  }) : songs = songs ?? [];

  void addSong(Song song) {
    if (!songs.any((s) => s.id == song.id)) {
      songs.add(song);
    }
  }

  void removeSong(String songId) {
    songs.removeWhere((s) => s.id == songId);
  }
}
