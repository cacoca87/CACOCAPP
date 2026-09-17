/// Reglas para los nombres de las bibliotecas/playlists.
///
/// Vive acá, y no dentro de una pantalla, porque hay tres lugares
/// distintos que crean o renombran una playlist (la barra lateral, el
/// diálogo de renombrar y el "Nueva playlist..." del menú ⋮ de cada
/// canción) y cada uno validaba por su cuenta -- o no validaba nada.
library;

/// Toda la música junta: la del servidor y la que ya estaba en el
/// celular.
///
/// Se llamaba "Principal (Drive)", y eso decía dos cosas que no son:
///
///  * **No hay ningún Drive.** La biblioteca vive en un bucket de
///    Cloudflare R2. Lo de "Drive" quedó de una versión anterior del
///    proyecto y nunca se corrigió, ni siquiera cuando se cambió de
///    servicio.
///  * **Ya no es solo eso.** Desde que la app lee la música guardada en
///    el propio teléfono, esta vista muestra las dos cosas mezcladas.
///
/// El nombre nuevo es además el que la app YA usaba para titular esta
/// pantalla: "Toda tu música". Ahora coinciden.
///
/// Nada de esto se guarda en el disco --es una variable en memoria que
/// dice qué se está mirando-- así que cambiarle el texto no rompe nada
/// de lo que hay guardado en el celular.
const String bibliotecaPrincipal = "Toda tu música";
const String bibliotecaFavoritos = "Favoritos";
const String bibliotecaRecientes = "Recientes";
const String bibliotecaMasEscuchadas = "Más Escuchadas";

/// Los nombres que la app usa para sus propias vistas. Ninguna playlist
/// puede llamarse así: las bibliotecas se buscan por nombre, así que
/// una playlist llamada "Recientes" quedaba tapada por la vista del
/// mismo nombre y era imposible de abrir.
///
/// Se declaran como constantes con nombre, y no como textos sueltos,
/// porque son CLAVES: la pantalla principal compara contra ellas para
/// saber qué mostrar. Escritas a mano estaban repetidas cuarenta y
/// cinco veces entre todos los archivos, y una sola letra distinta en
/// cualquiera de ellas rompía esa vista en silencio --sin error, sin
/// aviso: simplemente dejaba de coincidir--.
const List<String> nombresReservadosDeBiblioteca = [
  bibliotecaPrincipal,
  bibliotecaFavoritos,
  bibliotecaRecientes,
  bibliotecaMasEscuchadas,
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
