import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/carrera_logica.dart';

void main() {
  group('JuegoCarrera', () {
    test('arranca en el carril del medio, sin rivales y sin puntaje', () {
      final j = JuegoCarrera(semilla: 1);
      expect(j.carrilJugador, 1);
      expect(j.puntaje, 0);
      expect(j.terminado, isFalse);
      expect(j.rivales.expand((f) => f).any((r) => r), isFalse);
    });

    test('no se sale de la pista por ninguno de los dos lados', () {
      final j = JuegoCarrera(semilla: 1);
      j.moverIzquierda();
      j.moverIzquierda();
      j.moverIzquierda();
      expect(j.carrilJugador, 0);

      for (var i = 0; i < 5; i++) {
        j.moverDerecha();
      }
      expect(j.carrilJugador, JuegoCarrera.carriles - 1);
    });

    test('siempre queda al menos un carril libre por donde pasar', () {
      // Con muchos avances se generan muchas filas: ninguna puede venir
      // con los tres carriles ocupados, o el juego sería imposible.
      for (var semilla = 0; semilla < 25; semilla++) {
        final j = JuegoCarrera(semilla: semilla);
        for (var i = 0; i < 60; i++) {
          j.avanzar();
          for (final fila in j.rivales) {
            expect(fila.every((r) => r), isFalse,
                reason: 'una fila quedó sin ningún carril libre');
          }
        }
      }
    });

    test('chocar con un rival termina el juego', () {
      final j = JuegoCarrera(semilla: 1);
      j.rivales[j.filaJugador][j.carrilJugador] = true;
      j.avanzar();
      // Tras avanzar, ese rival salió; se lo pone de nuevo justo encima.
      j.rivales[j.filaJugador][j.carrilJugador] = true;
      j.moverIzquierda();
      j.moverDerecha();
      expect(j.terminado, isTrue);
    });

    test('cambiar de carril hacia un rival también cuenta como choque', () {
      final j = JuegoCarrera(semilla: 1);
      j.carrilJugador = 0;
      j.rivales[j.filaJugador][1] = true;
      j.moverDerecha();
      expect(j.terminado, isTrue);
    });

    test('esquivar un rival suma puntaje', () {
      final j = JuegoCarrera(semilla: 1);
      // Rival en la última fila, en un carril distinto al del jugador.
      final carrilLibre = j.carrilJugador == 0 ? 1 : 0;
      j.rivales[JuegoCarrera.filas - 1][carrilLibre] = true;
      j.avanzar();
      expect(j.puntaje, greaterThan(0));
    });

    test('acelera al subir de nivel', () {
      final j = JuegoCarrera(semilla: 1);
      final intervaloInicial = j.intervalo;
      j.nivel = 4;
      expect(j.intervalo, lessThan(intervaloInicial));
    });

    test('un juego terminado ya no avanza ni se mueve', () {
      final j = JuegoCarrera(semilla: 1);
      j.terminado = true;
      final carrilAntes = j.carrilJugador;
      j.moverIzquierda();
      j.avanzar();
      expect(j.carrilJugador, carrilAntes);
      expect(j.puntaje, 0);
    });

    test('reiniciar deja todo como al principio', () {
      final j = JuegoCarrera(semilla: 1);
      for (var i = 0; i < 30; i++) {
        j.avanzar();
      }
      j.terminado = true;
      j.reiniciar();
      expect(j.terminado, isFalse);
      expect(j.puntaje, 0);
      expect(j.carrilJugador, 1);
      expect(j.rivales.expand((f) => f).any((r) => r), isFalse);
    });
  });
}
