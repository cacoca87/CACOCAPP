import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/barra_de_progreso.dart';

void main() {
  group('cuando NO se sabe cuánto dura la canción', () {
    // El reproductor hacía de cuenta que duraba tres minutos. No hace
    // falta una conexión mala para llegar acá: la duración de cualquier
    // canción tarda un momento en conocerse.
    test('no se inventa una duración', () {
      final b = calcularBarraDeProgreso(
        posicion: const Duration(seconds: 30),
        duracion: null,
      );
      expect(b.textoDerecha, '--:--');
      expect(b.textoDerecha, isNot(contains('3:00')));
    });

    test('la barra no se puede arrastrar', () {
      // Antes se podía, y no se pasaba de los tres minutos: el resto de
      // una canción más larga quedaba fuera de alcance.
      final b = calcularBarraDeProgreso(
        posicion: const Duration(seconds: 30),
        duracion: null,
      );
      expect(b.sePuedeArrastrar, isFalse);
    });

    test('el tiempo que va SÍ se muestra: es lo único cierto que hay', () {
      final b = calcularBarraDeProgreso(
        posicion: const Duration(minutes: 1, seconds: 5),
        duracion: null,
      );
      expect(b.textoIzquierda, '1:05');
    });

    test('el máximo nunca es cero', () {
      // Un Slider con min == max tira un error en pantalla.
      final b = calcularBarraDeProgreso(
        posicion: Duration.zero,
        duracion: null,
      );
      expect(b.maximo, greaterThan(0));
      expect(b.valor, lessThanOrEqualTo(b.maximo));
    });

    test('una duración de cero cuenta como desconocida', () {
      // Es lo que informa un stream sin duración declarada.
      final b = calcularBarraDeProgreso(
        posicion: const Duration(seconds: 10),
        duracion: Duration.zero,
      );
      expect(b.sePuedeArrastrar, isFalse);
      expect(b.textoDerecha, '--:--');
    });
  });

  group('con la duración conocida', () {
    test('muestra los dos tiempos', () {
      final b = calcularBarraDeProgreso(
        posicion: const Duration(minutes: 1, seconds: 12),
        duracion: const Duration(minutes: 3, seconds: 45),
      );
      expect(b.textoIzquierda, '1:12');
      expect(b.textoDerecha, '3:45');
      expect(b.sePuedeArrastrar, isTrue);
    });

    test('el punto va donde corresponde', () {
      final b = calcularBarraDeProgreso(
        posicion: const Duration(minutes: 1),
        duracion: const Duration(minutes: 4),
      );
      expect(b.valor / b.maximo, closeTo(0.25, 0.001));
    });

    test('una canción de más de una hora se lee entera', () {
      // Los mixes largos: con el formateador viejo la hora desaparecía.
      final b = calcularBarraDeProgreso(
        posicion: const Duration(hours: 1, minutes: 5, seconds: 30),
        duracion: const Duration(hours: 2),
      );
      expect(b.textoIzquierda, '1:05:30');
      expect(b.textoDerecha, '2:00:00');
    });

    test('la barra NO se clava al llegar a los tres minutos', () {
      // El síntoma exacto del bug: en una canción de cinco minutos, a
      // los cuatro la barra ya estaba al final.
      final b = calcularBarraDeProgreso(
        posicion: const Duration(minutes: 4),
        duracion: const Duration(minutes: 5),
      );
      expect(b.valor / b.maximo, closeTo(0.8, 0.001));
      expect(b.textoDerecha, '5:00');
    });
  });

  group('mientras se arrastra', () {
    test('manda el dedo, no la reproducción', () {
      // Si no, cada aviso de posición --unas cinco veces por segundo--
      // le pisaría el arrastre a mitad de camino.
      final b = calcularBarraDeProgreso(
        posicion: const Duration(seconds: 10),
        duracion: const Duration(minutes: 4),
        valorMientrasArrastra: 120000, // el dedo en el minuto 2
      );
      expect(b.valor, 120000);
      expect(b.textoIzquierda, '2:00');
    });

    test('el tiempo de la izquierda sigue al dedo, no a la canción', () {
      final b = calcularBarraDeProgreso(
        posicion: const Duration(seconds: 3),
        duracion: const Duration(minutes: 4),
        valorMientrasArrastra: 90000,
      );
      expect(b.textoIzquierda, '1:30');
    });

    test('un arrastre pasado del final se recorta', () {
      final b = calcularBarraDeProgreso(
        posicion: Duration.zero,
        duracion: const Duration(minutes: 3),
        valorMientrasArrastra: 999999999,
      );
      expect(b.valor, b.maximo);
    });
  });

  group('valores raros que no tienen que reventar', () {
    test('una posición negativa se trata como cero', () {
      // Puede venir un instante al saltar hacia atrás.
      final b = calcularBarraDeProgreso(
        posicion: const Duration(seconds: -5),
        duracion: const Duration(minutes: 3),
      );
      expect(b.valor, 0);
      expect(b.textoIzquierda, '0:00');
    });

    test('una posición más allá del final se recorta', () {
      // Pasa al terminar la canción: la posición sigue un momento más.
      final b = calcularBarraDeProgreso(
        posicion: const Duration(minutes: 10),
        duracion: const Duration(minutes: 3),
      );
      expect(b.valor, b.maximo);
      expect(b.textoIzquierda, '3:00');
    });

    test('una duración negativa cuenta como desconocida', () {
      final b = calcularBarraDeProgreso(
        posicion: Duration.zero,
        duracion: const Duration(seconds: -1),
      );
      expect(b.sePuedeArrastrar, isFalse);
    });

    test('el valor nunca se sale del rango del Slider', () {
      // Un Slider con un valor fuera de [min, max] tira un error.
      final casos = [
        (const Duration(seconds: -100), const Duration(minutes: 3), null),
        (const Duration(hours: 5), const Duration(minutes: 3), null),
        (Duration.zero, null, null),
        (Duration.zero, const Duration(minutes: 3), -50000.0),
        (Duration.zero, const Duration(minutes: 3), 99999999.0),
      ];

      for (final (posicion, duracion, arrastre) in casos) {
        final b = calcularBarraDeProgreso(
          posicion: posicion,
          duracion: duracion,
          valorMientrasArrastra: arrastre,
        );
        expect(b.valor, greaterThanOrEqualTo(0),
            reason: 'valor negativo con $posicion / $duracion / $arrastre');
        expect(b.valor, lessThanOrEqualTo(b.maximo),
            reason: 'valor pasado del máximo con '
                '$posicion / $duracion / $arrastre');
      }
    });
  });
}
