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

/// `true` si esta dirección apunta a un archivo del celular que **ya no
/// está**.
///
/// POR QUÉ IMPORTA DISTINGUIRLO
///
/// Cuando el reproductor falla, la app supone que se cortó internet:
/// reintenta cinco veces esperando cada vez más, y si no lo logra dice
/// "Se perdió la conexión, reintentá cuando tengas señal".
///
/// Con un archivo del propio celular eso está mal dos veces. Primero,
/// reintentar no puede funcionar: el archivo no va a aparecer solo, así
/// que son cinco esperas de hasta treinta segundos para nada. Y
/// segundo, el mensaje es falso: no hay ningún problema de conexión.
///
/// Pasa de verdad y es fácil: borrás un MP3 del celular con el
/// administrador de archivos, y esa canción sigue en una playlist o era
/// la última que sonó. La app la intenta poner y no la encuentra.
///
/// [existe] se recibe de afuera para poder probar esto sin tocar el
/// disco.
bool esUnArchivoQueYaNoEsta(
  String direccion,
  bool Function(String ruta) existe,
) {
  final ruta = rutaDeArchivoDe(direccion);
  // `null` es algo de internet: ahí sí puede ser la conexión.
  if (ruta == null || ruta.isEmpty) return false;
  return !existe(ruta);
}
