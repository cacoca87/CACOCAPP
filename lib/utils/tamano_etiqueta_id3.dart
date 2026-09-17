/// Cuánto ocupa la etiqueta ID3 que va al principio de un MP3.
///
/// POR QUÉ EXISTE: PARA NO GASTAR DATOS MÓVILES AL PEDO
///
/// La app lee de adentro de cada MP3 su título, su artista, su álbum y
/// su carátula. Para eso no hace falta bajar la canción entera --esos
/// datos están todos al principio del archivo-- así que se le pedía al
/// servidor "mandame los primeros 512 KB".
///
/// El problema es que 512 KB es una apuesta a lo grande: una etiqueta
/// sin carátula ocupa unos pocos kilobytes, y una con carátula
/// normalmente entre 30 y 150. O sea que casi siempre se bajaba de más,
/// y por MUCHO.
///
/// Con una biblioteca de 160 canciones, la primera vez que se abre la
/// app eso son **80 megabytes de datos móviles**. Para leer unos
/// títulos.
///
/// Lo bueno es que no hay que adivinar: la propia etiqueta empieza
/// diciendo cuánto mide. Los primeros diez bytes traen ese número. Así
/// que ahora se pide un pedazo chico primero, se lee ahí cuánto hace
/// falta de verdad, y solo si no alcanzó se pide el resto.
library;

/// Cuántos bytes se piden en el primer intento.
///
/// Es un punto medio: le entra cómodo a una etiqueta sin carátula y a
/// la mayoría de las que sí la traen, así que casi siempre alcanza con
/// UN pedido. Y cuando no alcanza, esos 64 KB no se tiran: sirvieron
/// para saber exactamente cuánto pedir la segunda vez.
const int primerPedazoDeMp3 = 65536;

/// Tope de seguridad. Una etiqueta ID3 puede declarar hasta 256 MB, y
/// si un archivo viene con el dato corrupto no hay que salir a bajar
/// eso. Ninguna etiqueta de verdad se acerca ni de lejos.
const int maximoDeEtiquetaId3 = 2 * 1024 * 1024;

/// Cuántos bytes hay que tener para que la etiqueta esté completa, o
/// `null` si esto no empieza con una etiqueta ID3v2.
///
/// `null` no es un error: los MP3 sin etiqueta al principio existen (la
/// versión vieja, ID3v1, va al FINAL del archivo). En ese caso no hay
/// nada que calcular y lo que ya se bajó es todo lo que se va a usar.
int? tamanoDeLaEtiquetaId3(List<int> bytes) {
  // Hacen falta los diez del encabezado para poder leer nada.
  if (bytes.length < 10) return null;

  // Toda etiqueta ID3v2 empieza con las letras "ID3".
  if (bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) return null;

  // La versión: 0xFF no es válida y delata un archivo roto.
  if (bytes[3] == 0xFF || bytes[4] == 0xFF) return null;

  // El tamaño viene en cuatro bytes "sincroseguros": cada uno aporta
  // solo 7 bits, y el que sobra va siempre en cero. Es para que el
  // número no pueda parecerse por accidente al comienzo de un cuadro de
  // audio. Si alguno tiene ese bit encendido, el dato no es confiable.
  for (var i = 6; i <= 9; i++) {
    if (bytes[i] & 0x80 != 0) return null;
  }

  final tamanoDeclarado = (bytes[6] << 21) |
      (bytes[7] << 14) |
      (bytes[8] << 7) |
      bytes[9];

  // El número declarado NO cuenta los diez del encabezado.
  var total = 10 + tamanoDeclarado;

  // Si la etiqueta trae pie de página (bit 4 de las banderas), son diez
  // bytes más al final.
  final tieneFooter = bytes[5] & 0x10 != 0;
  if (tieneFooter) total += 10;

  if (total <= 10) return null;
  if (total > maximoDeEtiquetaId3) return maximoDeEtiquetaId3;
  return total;
}

/// `true` si con [bytesQueYaSeTienen] alcanza para leer la etiqueta
/// entera, o si no hay etiqueta que leer.
bool alcanzaConLoQueSeBajo(List<int> bytes, int bytesQueYaSeTienen) {
  final necesarios = tamanoDeLaEtiquetaId3(bytes);
  if (necesarios == null) return true;
  return bytesQueYaSeTienen >= necesarios;
}
