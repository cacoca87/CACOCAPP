import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/carrera_logica.dart';

void main() {
  group('JuegoCarrera', () {
    test('arranca en un carril del medio, sin rivales y sin puntaje', () {
      final j = JuegoCarrera(semilla: 1);
      expect(j.carrilJugador, JuegoCarrera.carriles ~/ 2);
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

    test('el juego sigue siendo ganable: nunca se tapan todos los carriles',
        () {
      // Con un solo rival por tanda siempre quedan carriles libres.
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

    test('hay lugar para cruzar: más de tres carriles', () {
      // La pista de tres carriles era el problema que reportaron: desde
      // un costado solo se alcanzaba el del medio, y si el rival estaba
      // ahí no había forma de pasar al otro lado.
      expect(JuegoCarrera.carriles, greaterThan(3));
    });

    test('entre un rival y el siguiente queda un respiro', () {
      // Un rival tarda 7 avances en cruzar la zona donde puede chocarte.
      // Si entrara uno nuevo cada 7, apenas se va uno ya está el otro
      // encima y no hay un solo avance de descanso.
      const avancesDentroDeLaZonaDeChoque = 7;
      expect(JuegoCarrera.avancesEntreRivales,
          greaterThan(avancesDentroDeLaZonaDeChoque));
    });

    test('dos rivales seguidos nunca vienen por el mismo carril', () {
      for (var semilla = 0; semilla < 40; semilla++) {
        final j = JuegoCarrera(semilla: semilla);
        final carrilesEnOrden = <int>[];
        for (var i = 0; i < 200; i++) {
          final antes = j.rivales.length;
          j.avanzar();
          if (j.rivales.length > antes) {
            carrilesEnOrden.add(j.rivales.last.carril);
          }
        }
        for (var i = 1; i < carrilesEnOrden.length; i++) {
          expect(carrilesEnOrden[i], isNot(carrilesEnOrden[i - 1]),
              reason:
                  'dos autos seguidos por el mismo lado (semilla $semilla)');
        }
      }
    });

    test('el carril sorteado siempre es uno válido', () {
      for (var semilla = 0; semilla < 40; semilla++) {
        final j = JuegoCarrera(semilla: semilla);
        for (var i = 0; i < 200; i++) {
          j.avanzar();
          for (final r in j.rivales) {
            expect(r.carril, inInclusiveRange(0, JuegoCarrera.carriles - 1));
          }
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
      expect(j.carrilJugador, JuegoCarrera.carriles ~/ 2);
      expect(j.rivales, isEmpty);
    });
  });
}
