/// Una "huella" corta y estable de un texto, para usar como parte del
/// nombre de un archivo de caché.
///
/// POR QUÉ NO SE USA `hashCode`
///
/// El `hashCode` de un texto en Dart sirve dentro de una misma
/// ejecución, pero NO se garantiza que sea el mismo la próxima vez que
/// arranque la app. Para algo que se guarda en el disco y se tiene que
/// volver a encontrar mañana, eso lo hace inservible: la caché entera
/// quedaría huérfana en cada actualización.
///
/// Esta cuenta (FNV-1a de 32 bits) da siempre el mismo resultado para
/// el mismo texto, en cualquier celular y en cualquier versión.
library;

String huellaCorta(String texto) {
  // Números del algoritmo FNV-1a de 32 bits.
  var h = 0x811c9dc5;
  for (final unidad in texto.codeUnits) {
    h ^= unidad;
    // Se recorta a 32 bits en cada vuelta: en Dart los enteros son de
    // 64, y sin recortar el resultado no coincidiría con la cuenta
    // estándar.
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(8, '0');
}
