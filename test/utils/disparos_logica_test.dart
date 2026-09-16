import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/disparos_logica.dart';

void main() {
  group('JuegoDisparos', () {
    test('arranca con el cañón al medio, sin bloques ni balas', () {
      final j = JuegoDisparos(semilla: 1);
      expect(j.columnaCanon, JuegoDisparos.columnas ~/ 2);
      expect(j.balas, isEmpty);
      expect(j.bloques.expand((f) => f).any((b) => b), isFalse);
      expect(j.puntaje, 0);
      expect(j.terminado, isFalse);
    });

    test('el cañón no se sale por ninguno de los dos lados', () {
      final j = JuegoDisparos(semilla: 1);
      for (var i = 0; i < JuegoDisparos.columnas + 3; i++) {
        j.moverIzquierda();
      }
      expect(j.columnaCanon, 0);

      for (var i = 0; i < JuegoDisparos.columnas * 2; i++) {
        j.moverDerecha();
      }
      expect(j.columnaCanon, JuegoDisparos.columnas - 1);
    });

    test('disparar pone una bala arriba del cañón', () {
      final j = JuegoDisparos(semilla: 1);
      j.disparar();
      expect(j.balas.length, 1);
      expect(j.balas.first.x, j.columnaCanon);
      expect(j.balas.first.y, JuegoDisparos.filaCanon - 1);
    });

    test('hay un tope de balas en vuelo', () {
      final j = JuegoDisparos(semilla: 1);
      for (var i = 0; i < 10; i++) {
        j.disparar();
      }
      expect(j.balas.length, lessThanOrEqualTo(3));
    });

    test('las balas suben y se van por arriba', () {
      final j = JuegoDisparos(semilla: 1);
      j.disparar();
      final alturaInicial = j.balas.first.y;
      j.avanzar();
      expect(j.balas.first.y, alturaInicial - 1);

      for (var i = 0; i < JuegoDisparos.filas + 2; i++) {
        j.avanzar();
      }
      expect(j.balas, isEmpty);
    });

    test('una bala destruye el bloque que tiene encima y suma puntaje', () {
      final j = JuegoDisparos(semilla: 1);
      final fila = JuegoDisparos.filaCanon - 2;
      j.bloques[fila][j.columnaCanon] = true;
      j.disparar();

      j.avanzar();

      expect(j.bloques[fila][j.columnaCanon], isFalse);
      expect(j.puntaje, greaterThan(0));
      expect(j.balas, isEmpty, reason: 'la bala se consume al impactar');
    });

    test('un bloque pegado al cañón se destruye de un tiro', () {
      final j = JuegoDisparos(semilla: 1);
      // Justo donde nace la bala. Antes la atravesaba: el impacto solo
      // se revisaba después de que la bala subiera un casillero.
      j.bloques[JuegoDisparos.filaCanon - 1][j.columnaCanon] = true;
      j.disparar();
      expect(j.bloques[JuegoDisparos.filaCanon - 1][j.columnaCanon], isFalse);
      expect(j.puntaje, greaterThan(0));
      expect(j.balas, isEmpty);
    });
    test('una bala no destruye un bloque de otra columna', () {
      final j = JuegoDisparos(semilla: 1);
      final otraColumna = j.columnaCanon == 0 ? 1 : 0;
      final fila = JuegoDisparos.filaCanon - 2;
      j.bloques[fila][otraColumna] = true;
      j.disparar();
      j.avanzar();
      expect(j.bloques[fila][otraColumna], isTrue);
      expect(j.puntaje, 0);
    });

    test('si un bloque llega al cañón se termina el juego', () {
      final j = JuegoDisparos(semilla: 1);
      j.bloques[JuegoDisparos.filas - 2][0] = true;
      for (var i = 0; i < JuegoDisparos.pasosEntreBajadas; i++) {
        j.avanzar();
      }
      expect(j.terminado, isTrue);
    });

    test('las filas nuevas nunca vienen llenas', () {
      for (var semilla = 0; semilla < 20; semilla++) {
        final j = JuegoDisparos(semilla: semilla);
        for (var i = 0; i < 200; i++) {
          j.avanzar();
          if (j.terminado) break;
          for (final fila in j.bloques) {
            expect(fila.every((b) => b), isFalse,
                reason: 'una fila vino tapada de punta a punta');
          }
        }
      }
    });

    test('acelera al subir de nivel', () {
      final j = JuegoDisparos(semilla: 1);
      final intervaloInicial = j.intervalo;
      j.nivel = 4;
      expect(j.intervalo, lessThan(intervaloInicial));
    });

    test('la vista marca cañón, balas y bloques por separado', () {
      final j = JuegoDisparos(semilla: 1);
      j.bloques[3][2] = true;
      j.disparar();
      final v = j.vista(colorCanon: 1, colorBala: 2, colorBloque: 3);
      expect(v.length, JuegoDisparos.filas);
      expect(v[0].length, JuegoDisparos.columnas);
      expect(v[JuegoDisparos.filaCanon][j.columnaCanon], 1);
      expect(v.expand((f) => f).where((c) => c == 2).length, 1);
      expect(v[3][2], 3);
    });

    test('un juego terminado ya no dispara ni avanza', () {
      final j = JuegoDisparos(semilla: 1);
      j.terminado = true;
      j.disparar();
      j.avanzar();
      expect(j.balas, isEmpty);
      expect(j.puntaje, 0);
    });

    test('reiniciar deja todo como al principio', () {
      final j = JuegoDisparos(semilla: 1);
      for (var i = 0; i < 50; i++) {
        j.avanzar();
      }
      j.disparar();
      j.terminado = true;
      j.reiniciar();
      expect(j.terminado, isFalse);
      expect(j.puntaje, 0);
      expect(j.balas, isEmpty);
      expect(j.bloques.expand((f) => f).any((b) => b), isFalse);
      expect(j.columnaCanon, JuegoDisparos.columnas ~/ 2);
    });
  });

  test('Point se compara por valor (base de los choques)', () {
    expect(const Point(1, 2), const Point(1, 2));
  });
}
