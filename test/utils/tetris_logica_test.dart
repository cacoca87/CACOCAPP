import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/tetris_logica.dart';

void main() {
  group('rotarMatriz', () {
    test('gira 90 grados en sentido horario', () {
      final original = [
        [1, 2],
        [3, 4],
      ];
      expect(rotarMatriz(original), [
        [3, 1],
        [4, 2],
      ]);
    });

    test('cuatro rotaciones vuelven al punto de partida', () {
      final original = [
        [0, 3, 0],
        [3, 3, 3],
        [0, 0, 0],
      ];
      var m = original;
      for (var i = 0; i < 4; i++) {
        m = rotarMatriz(m);
      }
      expect(m, original);
    });
  });

  group('puntajePorLineas', () {
    test('cuatro líneas juntas rinden más que cuatro de a una', () {
      expect(puntajePorLineas(4, 1), greaterThan(puntajePorLineas(1, 1) * 4));
    });

    test('el nivel multiplica el puntaje', () {
      expect(puntajePorLineas(1, 3), puntajePorLineas(1, 1) * 3);
    });
  });

  group('JuegoTetris', () {
    test('arranca con el tablero vacío y una pieza en juego', () {
      final j = JuegoTetris(semilla: 1);
      expect(j.terminado, isFalse);
      expect(j.puntaje, 0);
      expect(j.forma, isNotNull);
      expect(j.tablero.expand((f) => f).every((c) => c == 0), isTrue);
    });

    test('no deja salirse por los costados', () {
      final j = JuegoTetris(semilla: 1);
      for (var i = 0; i < 20; i++) {
        j.moverIzquierda();
      }
      // Ya contra la pared, otro movimiento tiene que ser rechazado.
      expect(j.moverIzquierda(), isFalse);

      for (var i = 0; i < 40; i++) {
        j.moverDerecha();
      }
      expect(j.moverDerecha(), isFalse);
    });

    test('la caída rápida deja la pieza apoyada en el piso', () {
      final j = JuegoTetris(semilla: 1);
      j.caidaRapida();
      // La última fila del tablero tiene que haber quedado con algo.
      final ultimasFilas = j.tablero.sublist(JuegoTetris.filas - 4);
      expect(ultimasFilas.expand((f) => f).any((c) => c != 0), isTrue);
    });

    test('una fila completa se elimina y suma puntaje', () {
      final j = JuegoTetris(semilla: 1);
      // Se arma a mano una fila a la que le falta una sola celda, y se
      // tapa el resto para que la pieza que caiga la complete.
      for (var x = 0; x < JuegoTetris.columnas; x++) {
        j.tablero[JuegoTetris.filas - 1][x] = 1;
      }
      final lineasAntes = j.lineasHechas;

      // Al fijar cualquier pieza se revisan las líneas completas.
      j.caidaRapida();

      expect(j.lineasHechas, greaterThan(lineasAntes));
      expect(j.puntaje, greaterThan(0));
      // La fila de abajo ya no puede estar completa con los mismos
      // valores: se eliminó y bajó todo lo de arriba.
      expect(j.tablero[JuegoTetris.filas - 1].every((c) => c == 1), isFalse);
    });

    test('el juego termina cuando la pila llega arriba', () {
      final j = JuegoTetris(semilla: 1);
      // Se llena casi todo, dejando la última COLUMNA libre: si se
      // llenaran filas enteras se eliminarían solas por estar completas
      // y el tablero quedaría vacío otra vez.
      for (var y = 0; y < JuegoTetris.filas; y++) {
        for (var x = 0; x < JuegoTetris.columnas - 1; x++) {
          j.tablero[y][x] = 1;
        }
      }
      j.caidaRapida();
      expect(j.terminado, isTrue);
    });

    test('acelera al subir de nivel', () {
      final j = JuegoTetris(semilla: 1);
      final intervaloInicial = j.intervalo;
      j.nivel = 5;
      expect(j.intervalo, lessThan(intervaloInicial));
    });

    test('la vista incluye la pieza que está cayendo', () {
      final j = JuegoTetris(semilla: 1);
      final ocupadasEnTablero =
          j.tablero.expand((f) => f).where((c) => c != 0).length;
      final ocupadasEnVista =
          j.vista.expand((f) => f).where((c) => c != 0).length;
      expect(ocupadasEnTablero, 0);
      expect(ocupadasEnVista, greaterThan(0));
    });

    test('la vista es una copia: tocarla no altera el juego', () {
      final j = JuegoTetris(semilla: 1);
      final v = j.vista;
      v[0][0] = 9;
      expect(j.tablero[0][0], 0);
    });

    test('reiniciar deja todo como al principio', () {
      final j = JuegoTetris(semilla: 1);
      j.puntaje = 500;
      j.terminado = true;
      j.reiniciar();
      expect(j.puntaje, 0);
      expect(j.terminado, isFalse);
      expect(j.nivel, 1);
    });
  });
}
