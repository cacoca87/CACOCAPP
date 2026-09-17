import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/tamano_etiqueta_id3.dart';

/// Leer cuánto mide la etiqueta que va al principio de un MP3.
///
/// Sirve para no bajar de más: antes se pedían 512 KB de cada canción
/// por si acaso, y con una biblioteca de 160 temas eso son 80 MB de
/// datos móviles la primera vez que se abre la app. La etiqueta dice
/// ella misma cuánto ocupa; solo hay que leerlo.

/// Arma un encabezado ID3v2 de verdad, con el tamaño metido como lo
/// hace el formato: cuatro bytes de siete bits cada uno.
List<int> _encabezado(int tamanoDelContenido, {bool conFooter = false}) {
  return [
    0x49, 0x44, 0x33, // "ID3"
    0x03, 0x00, // versión 2.3.0
    conFooter ? 0x10 : 0x00, // banderas
    (tamanoDelContenido >> 21) & 0x7F,
    (tamanoDelContenido >> 14) & 0x7F,
    (tamanoDelContenido >> 7) & 0x7F,
    tamanoDelContenido & 0x7F,
  ];
}

void main() {
  group('tamanoDeLaEtiquetaId3', () {
    test('una etiqueta chica, sin carátula', () {
      // Título, artista y álbum en texto: unos pocos kilobytes.
      expect(tamanoDeLaEtiquetaId3(_encabezado(3000)), 3010);
    });

    test('una etiqueta con carátula', () {
      // Una tapa de 600x600 pesa entre 30 y 150 KB.
      expect(tamanoDeLaEtiquetaId3(_encabezado(120000)), 120010);
    });

    test('el número se arma con siete bits por byte, no con ocho', () {
      // Es la parte del formato que más fácil se programa mal: si se
      // leyera como un número normal de cuatro bytes, daría cualquier
      // cosa. 0x7F 0x7F 0x7F 0x7F es el máximo que entra en cuatro
      // bytes de siete bits.
      final maximo = tamanoDeLaEtiquetaId3([
        0x49, 0x44, 0x33, 0x03, 0x00, 0x00, //
        0x7F, 0x7F, 0x7F, 0x7F,
      ]);
      // 2^28 - 1 son 268435455, más el encabezado. Pasa del tope de
      // seguridad, así que se recorta.
      expect(maximo, maximoDeEtiquetaId3);
    });

    test('con pie de página son diez bytes más', () {
      expect(tamanoDeLaEtiquetaId3(_encabezado(5000, conFooter: true)), 5020);
      expect(tamanoDeLaEtiquetaId3(_encabezado(5000)), 5010);
    });

    test('un archivo que NO empieza con etiqueta da null', () {
      // Los MP3 sin etiqueta al principio existen: la versión vieja va
      // al final del archivo. No es un error.
      expect(tamanoDeLaEtiquetaId3([0xFF, 0xFB, 0x90, 0x00, 0, 0, 0, 0, 0, 0]),
          isNull);
    });

    test('muy pocos bytes para decidir: null', () {
      expect(tamanoDeLaEtiquetaId3([0x49, 0x44, 0x33]), isNull);
      expect(tamanoDeLaEtiquetaId3(const []), isNull);
    });

    test('un tamaño con el bit prohibido encendido no se cree', () {
      // Ese bit tiene que ir en cero siempre. Si viene en uno, el dato
      // está corrupto y creerle podría hacer bajar cualquier cosa.
      final roto = _encabezado(3000);
      roto[7] = 0x80;
      expect(tamanoDeLaEtiquetaId3(roto), isNull);
    });

    test('una versión imposible no se cree', () {
      final roto = _encabezado(3000);
      roto[3] = 0xFF;
      expect(tamanoDeLaEtiquetaId3(roto), isNull);
    });

    test('un tamaño declarado enorme se recorta al tope de seguridad', () {
      // Una etiqueta puede declarar hasta 256 MB. Si un archivo viene
      // con el dato corrupto, no hay que salir a bajar eso.
      expect(tamanoDeLaEtiquetaId3(_encabezado(200 * 1024 * 1024)),
          maximoDeEtiquetaId3);
    });

    test('una etiqueta vacía da null', () {
      expect(tamanoDeLaEtiquetaId3(_encabezado(0)), isNull);
    });
  });

  group('alcanzaConLoQueSeBajo', () {
    test('la etiqueta entra en el primer pedazo: no se pide más', () {
      final bytes = _encabezado(30000);
      expect(alcanzaConLoQueSeBajo(bytes, primerPedazoDeMp3), isTrue);
    });

    test('la etiqueta NO entra: hay que pedir el resto', () {
      final bytes = _encabezado(200000);
      expect(alcanzaConLoQueSeBajo(bytes, primerPedazoDeMp3), isFalse);
    });

    test('sin etiqueta al principio, no hay nada más que pedir', () {
      expect(
        alcanzaConLoQueSeBajo([0xFF, 0xFB, 0x90, 0, 0, 0, 0, 0, 0, 0], 1000),
        isTrue,
      );
    });

    test('justo en el límite alcanza', () {
      // Una etiqueta de exactamente el tamaño del primer pedazo.
      final bytes = _encabezado(primerPedazoDeMp3 - 10);
      expect(alcanzaConLoQueSeBajo(bytes, primerPedazoDeMp3), isTrue);
      // Y uno más ya no.
      final unoMas = _encabezado(primerPedazoDeMp3 - 9);
      expect(alcanzaConLoQueSeBajo(unoMas, primerPedazoDeMp3), isFalse);
    });
  });

  group('cuánto se ahorra de verdad', () {
    test('una canción sin carátula: de 512 KB a 64', () {
      const loQueSeBajabaAntes = 524288;
      final bytes = _encabezado(4000);
      expect(alcanzaConLoQueSeBajo(bytes, primerPedazoDeMp3), isTrue);
      expect(primerPedazoDeMp3, lessThan(loQueSeBajabaAntes));
      // Ocho veces menos.
      expect(loQueSeBajabaAntes ~/ primerPedazoDeMp3, 8);
    });

    test('una canción con carátula grande: se pide lo justo', () {
      final bytes = _encabezado(150000);
      final necesario = tamanoDeLaEtiquetaId3(bytes)!;
      expect(necesario, 150010);
      // Sigue siendo menos que los 512 KB de antes, aun en el peor
      // caso normal.
      expect(necesario, lessThan(524288));
    });
  });
}
