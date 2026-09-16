class Song {
  final String id;
  final String title;
  String artist; // mutable: se actualiza cuando llega el tag ID3 real (TPE1)
  String album; // mutable: se actualiza cuando llega el tag ID3 real (TALB)
  final String url;
  final String coverUrl;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.url,
    required this.coverUrl,
  });
}
