class Song {
  final String id;
  final String title;
  final String artist;
  String album; // mutable: se actualiza cuando llega el tag ID3 real
  final String url;
  final String coverUrl;
  List<String> playlists;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.url,
    required this.coverUrl,
    List<String>? playlists,
  }) : playlists = playlists ?? [];
}