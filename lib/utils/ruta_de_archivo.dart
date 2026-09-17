/// Convierte lo que la app usa como "dirección de una canción" en una
/// ruta de archivo que `File` entienda, o `null` si no es un archivo
/// del celular sino algo de internet.
///
/// POR QUÉ HACE FALTA
///
/// Cuando una canción está descargada, la app guarda su dirección en
/// formato `file:///data/user/0/.../descargas/xxx.mp3`. Eso es una
/// DIRECCIÓN, no una ruta: lleva el `file://` adelante. `File` espera
/// una ruta pelada (`/data/user/0/.../xxx.mp3`).
///
/// Dárselo tal cual no falla con un error: crea un archivo cuyo nombre
/// es, literalmente, "file:///data/...". Ese archivo no existe nunca,
/// así que la comprobación decía tranquilamente "no está" y todo
/// seguía como si la canción no tuviera nada adentro.
///
/// Lo que eso rompía: las canciones DESCARGADAS se quedaban sin su
/// carátula en la pantalla de bloqueo, y la app salía a buscarla a
/// internet -- justo lo contrario de para qué se descarga una canción.
/// Y su letra incrustada tampoco se leía nunca.
library;

String? rutaDeArchivoDe(String direccion) {
  if (direccion.isEmpty) return null;
  if (direccion.startsWith('http://') || direccion.startsWith('https://')) {
    return null;
  }
  if (direccion.startsWith('file://')) {
    try {
      return Uri.parse(direccion).toFilePath();
    } catch (_) {
      return null;
    }
  }
  // Ya venía como ruta pelada.
  return direccion;
}
