import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/carrera_logica.dart';

void main() {
  group('JuegoCarrera', () {
    test('arranca en el carril del medio, sin rivales y sin puntaje', () {
      final j = JuegoCarrera(semilla: 1);
      expect(j.carrilJugador, 1);
      expect(j.puntaje, 0);
      expect(j.terminado, isFalse);
      expect(j.rivales, isEmpty);
    });

    test('no se sale de la pista por ninguno de los dos lados', () {
      final j = JuegoCarrera(semilla: 1);
      for (var i = 0; i < 5; i++) {
        j.moverIzquierda();
      }
      expect(j.carrilJugador, 0);

      for (var i = 0; i < 8; i++) {
        j.moverDerecha();
      }
      expect(j.carrilJugador, JuegoCarrera.carriles - 1);
    });

    test('chocar con un rival del mismo carril termina el juego', () {
      final j = JuegoCarrera(semilla: 1);
      j.rivales.add(AutoRival(carril: j.carrilJugador, fila: j.filaJugador));
      j.avanzar();
      expect(j.terminado, isTrue);
    });

    test('un rival en otro carril no choca', () {
      final j = JuegoCarrera(semilla: 1);
      final otroCarril = j.carrilJugador == 0 ? 1 : 0;
      j.rivales.add(AutoRival(carril: otroCarril, fila: j.filaJugador));
      j.avanzar();
      expect(j.terminado, isFalse);
    });

    test('cambiar de carril hacia un rival también cuenta como choque', () {
      final j = JuegoCarrera(semilla: 1);
      j.carrilJugador = 0;
      j.rivales.add(AutoRival(carril: 1, fila: j.filaJugador));
      j.moverDerecha();
      expect(j.terminado, isTrue);
    });

    test('un rival que todavía viene lejos no choca', () {
      final j = JuegoCarrera(semilla: 1);
      j.rivales.add(AutoRival(carril: j.carrilJugador, fila: 0));
      j.avanzar();
      expect(j.terminado, isFalse);
    });

    test('esquivar un rival suma puntaje y lo saca de la pista', () {
      final j = JuegoCarrera(semilla: 1);
      final otroCarril = j.carrilJugador == 0 ? 1 : 0;
      j.rivales
          .add(AutoRival(carril: otroCarril, fila: JuegoCarrera.filas - 1));
      j.avanzar();
      expect(j.puntaje, greaterThan(0));
      expect(j.rivales, isEmpty);
    });

    test('los rivales entran desde arriba, fuera de la pista', () {
      final j = JuegoCarrera(semilla: 3);
      for (var i = 0; i < JuegoCarrera.avancesEntreRivales; i++) {
        j.avanzar();
      }
      expect(j.rivales, isNotEmpty);
      // Recién entrando: su fila de arriba todavía es negativa o apenas 0.
      expect(j.rivales.first.fila, lessThanOrEqualTo(0));
    });

    test('la vista dibuja el auto con su forma, no un solo casillero', () {
      final j = JuegoCarrera(semilla: 1);
      final v = j.vista(colorJugador: 1, colorRival: 3);
      expect(v.length, JuegoCarrera.filas);
      expect(v[0].length, JuegoCarrera.columnas);

      final casillerosDelJugador =
          v.expand((f) => f).where((c) => c == 1).length;
      final casillerosDeLaForma =
          formaAuto.expand((f) => f).where((c) => c != 0).length;
      expect(casillerosDelJugador, casillerosDeLaForma);
      expect(casillerosDelJugador, greaterThan(1));
    });

    test('el juego sigue siendo ganable: nunca se tapan los tres carriles', () {
      // Con un solo rival por tanda siempre quedan dos carriles libres.
      for (var semilla = 0; semilla < 25; semilla++) {
        final j = JuegoCarrera(semilla: semilla);
        for (var i = 0; i < 120; i++) {
          j.avanzar();
          if (j.terminado) break;
          final carrilesOcupados = j.rivales
              .where((r) =>
                  r.fila + JuegoCarrera.altoAuto - 1 >= j.filaJugador &&
                  r.fila <= JuegoCarrera.filas - 1)
              .map((r) => r.carril)
              .toSet();
          expect(carrilesOcupados.length, lessThan(JuegoCarrera.carriles),
              reason: 'no quedó ningún carril libre');
        }
      }
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
      for (var i = 0; i < 40; i++) {
        j.avanzar();
      }
      j.terminado = true;
      j.reiniciar();
      expect(j.terminado, isFalse);
      expect(j.puntaje, 0);
      expect(j.carrilJugador, 1);
      expect(j.rivales, isEmpty);
    });
  });
}
