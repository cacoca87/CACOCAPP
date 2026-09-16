/// Reglas para los nombres de las bibliotecas/playlists.
///
/// Vive acá, y no dentro de una pantalla, porque hay tres lugares
/// distintos que crean o renombran una playlist (la barra lateral, el
/// diálogo de renombrar y el "Nueva playlist..." del menú ⋮ de cada
/// canción) y cada uno validaba por su cuenta -- o no validaba nada.
library;

/// Los nombres que la app usa para sus propias vistas. Ninguna playlist
/// puede llamarse así: las bibliotecas se buscan por nombre, así que
/// una playlist llamada "Recientes" quedaba tapada por la vista del
/// mismo nombre y era imposible de abrir.
const List<String> nombresReservadosDeBiblioteca = [
  "Principal (Drive)",
  "Favoritos",
  "Recientes",
  "Más Escuchadas",
];

/// Devuelve el motivo por el que [nombre] no sirve como nombre de
/// biblioteca, o `null` si está bien.
///
/// [nombresExistentes] son los nombres de las playlists que ya hay.
/// [nombreQueSeReemplaza] es el nombre actual cuando se está
/// renombrando: choca consigo mismo y no tiene que contar como
/// duplicado.
String? errorDeNombreDeBiblioteca(
  String nombre, {
  required Iterable<String> nombresExistentes,
  String? nombreQueSeReemplaza,
}) {
  final limpio = nombre.trim();
  if (limpio.isEmpty) return 'Escribí un nombre para la biblioteca.';
  if (nombresReservadosDeBiblioteca.contains(limpio)) {
    return '"$limpio" es un nombre reservado de la app. Probá con otro.';
  }
  if (limpio != nombreQueSeReemplaza && nombresExistentes.contains(limpio)) {
    return 'Ya tenés una biblioteca llamada "$limpio".';
  }
  return null;
}
