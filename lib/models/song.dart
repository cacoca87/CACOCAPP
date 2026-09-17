class Song {
  final String id;

  /// Mutable, igual que [artist] y [album]: se reemplaza por el título
  /// REAL del tag ID3 (TIT2) cuando el MP3 lo trae.
  ///
  /// Hace falta porque el nombre del archivo a veces no dice cómo se
  /// llama la canción. Caso comprobado: varios temas del disco "Libre"
  /// de Amén se mostraban todos como "Amén", que es el nombre de la
  /// banda, no el de la canción. Con el título equivocado la letra
  /// nunca se puede encontrar, porque se busca una canción que no
  /// existe.
  String title;

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
