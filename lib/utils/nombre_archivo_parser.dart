/// Deduce el título y el artista a partir del nombre del archivo MP3.
///
/// Es solo un respaldo: cuando el archivo trae etiquetas ID3 reales,
/// `pantalla_principal.dart` las lee y pisa lo que se adivine acá. Pero
/// para los archivos sin etiquetas, esto es lo único que hay, así que
/// conviene que acierte.
///
/// Vive aparte de `drive_service.dart` para poder probarlo sin salir a
/// la red, igual que `extension_guesser.dart` y `lyrics_parsing.dart`.
library;

const String artistaDesconocido = 'Artista Desconocido';

class TituloYArtista {
  final String titulo;
  final String artista;
  const TituloYArtista(this.titulo, this.artista);
}

/// Palabras que describen la VERSIÓN de una grabación, no a quien la
/// toca. Hacen falta porque hay archivos con tres partes donde la del
/// medio no es el artista: en "Black Dog - Remaster - Led Zeppelin" la
/// regla vieja (tomar siempre la segunda parte) dejaba el artista como
/// "Remaster", y en la pantalla de Artistas aparecía "Remaster" como si
/// fuera una banda.
const Set<String> _calificadores = {
  'remaster',
  'remastered',
  'remasterizado',
  'remaster version',
  'remastered version',
  'live',
  'en vivo',
  'remix',
  'original',
  'version',
  'versión',
  'edit',
  'radio edit',
  'single',
  'single version',
  'album version',
  'mono',
  'stereo',
  'demo',
  'acoustic',
  'acústico',
  'deluxe',
  'bonus track',
};

/// Una parte es un "calificador" si, sacándole el año, queda una de las
/// palabras de arriba. Así "2012 Remaster", "Remaster 2009" y
/// "Remaster" cuentan todos como lo mismo, sin tener que listarlos.
bool _esCalificador(String parte) {
  final limpio = parte
      .toLowerCase()
      .replaceAll(RegExp(r'\b(19|20)\d{2}\b'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return limpio.isEmpty || _calificadores.contains(limpio);
}

/// [nombreLimpio] es el nombre del archivo sin la extensión `.mp3`.
///
/// [artistasQueVanPrimero] son los artistas cuyos archivos están
/// nombrados al revés que el resto ("Artista - Título" en vez de
/// "Título - Artista"); se comparan sin distinguir mayúsculas.
TituloYArtista deducirTituloYArtista(
  String nombreLimpio, {
  List<String> artistasQueVanPrimero = const [],
}) {
  final nombre = nombreLimpio.trim();
  if (!nombre.contains(' - ')) {
    return TituloYArtista(nombre, artistaDesconocido);
  }

  final partes = nombre.split(' - ').map((p) => p.trim()).toList();
  final primera = partes.first;

  final vaPrimero = artistasQueVanPrimero
      .any((a) => a.toLowerCase() == primera.toLowerCase());
  if (vaPrimero) {
    return TituloYArtista(partes.sublist(1).join(' - '), primera);
  }

  // "Título - Artista". Con tres o más partes se toma la primera que no
  // sea un calificador de versión, que generaliza la regla vieja de
  // "siempre la segunda" sin romper los casos de dos partes.
  final resto = partes.sublist(1);
  final artista = resto.firstWhere(
    (p) => !_esCalificador(p),
    orElse: () => '',
  );

  return TituloYArtista(
    primera,
    artista.isEmpty ? artistaDesconocido : artista,
  );
}

/// El nombre del archivo, sin carpeta ni extensión, sacado de su URL.
String nombreDeArchivoDeUrl(String url) {
  final uri = Uri.tryParse(url);
  final ultimo = (uri != null && uri.pathSegments.isNotEmpty)
      // `pathSegments` YA viene decodificado: volver a decodificarlo
      // reventaba con cualquier nombre que tuviera un signo de
      // porcentaje.
      ? uri.pathSegments.last
      : url;
  return ultimo.replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '').trim();
}

/// Corrige el título cuando YA se sabe quién es el artista de verdad.
///
/// Devuelve el título corregido, o `null` si no hay nada que corregir.
///
/// POR QUÉ HACE FALTA
///
/// [deducirTituloYArtista] tiene que adivinar si un archivo se llama
/// "Título - Artista" o "Artista - Título", y para eso usa una lista de
/// artistas conocidos que van primero. Esa lista tiene seis nombres:
/// cualquier disco cuyos archivos estén nombrados al revés y cuyo
/// artista no esté ahí queda con el título y el artista cambiados.
///
/// Pasó de verdad y se notó: los temas del disco "Libre" de Amén se
/// llamaban "Amén - Te Quiero.mp3", así que la app mostraba tres
/// canciones distintas todas tituladas "Amén" (el nombre de la banda).
/// Con el título equivocado la letra tampoco aparecía nunca, porque se
/// buscaba una canción que no existe.
///
/// Pero el tag ID3 del propio MP3 SÍ dice quién es el artista. Sabiendo
/// eso, ya no hay que adivinar: si la primera parte del nombre del
/// archivo es el artista, entonces el título es el resto. Sale gratis,
/// porque ese dato ya se pidió para corregir el artista.
String? tituloSabiendoElArtista(String nombreLimpio, String artistaReal) {
  final nombre = nombreLimpio.trim();
  final artista = artistaReal.trim();
  if (nombre.isEmpty || artista.isEmpty || !nombre.contains(' - ')) return null;

  final partes = nombre.split(' - ').map((p) => p.trim()).toList();
  bool esElArtista(String parte) =>
      parte.toLowerCase() == artista.toLowerCase();

  // "Artista - Título": el título es todo lo que viene después.
  if (esElArtista(partes.first)) {
    final resto = partes.sublist(1).join(' - ').trim();
    return resto.isEmpty ? null : resto;
  }

  // "Título - Artista": ya estaba bien, no se toca.
  return null;
}
