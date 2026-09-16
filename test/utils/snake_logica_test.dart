import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/snake_logica.dart';

void main() {
  group('JuegoSnake', () {
    test('arranca con el largo inicial, mirando a la derecha', () {
      final j = JuegoSnake(semilla: 1);
      expect(j.largo, JuegoSnake.largoInicial);
      expect(j.direccion, Direccion.derecha);
      expect(j.terminado, isFalse);
      expect(j.puntaje, 0);
    });

    test('la comida nunca aparece encima de la serpiente', () {
      for (var semilla = 0; semilla < 30; semilla++) {
        final j = JuegoSnake(semilla: semilla);
        expect(j.cuerpo.contains(j.comida), isFalse);
      }
    });

    test('avanzar mueve la cabeza sin cambiar el largo', () {
      final j = JuegoSnake(semilla: 1);
      final cabezaAntes = j.cuerpo.first;
      final largoAntes = j.largo;
      j.avanzar();
      expect(j.cuerpo.first, Point(cabezaAntes.x + 1, cabezaAntes.y));
      expect(j.largo, largoAntes);
    });

    test('no se puede dar media vuelta sobre el propio cuello', () {
      final j = JuegoSnake(semilla: 1);
      j.girar(Direccion.izquierda); // va a la derecha: se ignora
      j.avanzar();
      expect(j.direccion, Direccion.derecha);
    });

    test('girar en ángulo recto sí funciona', () {
      final j = JuegoSnake(semilla: 1);
      j.girar(Direccion.abajo);
      j.avanzar();
      expect(j.direccion, Direccion.abajo);
    });

    test('dos giros dentro del mismo paso no la hacen retroceder', () {
      // Yendo a la derecha: "arriba" y enseguida "izquierda". Si se
      // aplicaran los dos, quedaría yendo a la izquierda, o sea al revés
      // de como venía, y se comería su propio cuello.
      final j = JuegoSnake(semilla: 1);
      j.girar(Direccion.arriba);
      j.girar(Direccion.izquierda);
      j.avanzar();
      expect(j.direccion, Direccion.arriba);
      expect(j.terminado, isFalse);
    });

    test('comer suma puntaje, alarga y mueve la comida', () {
      final j = JuegoSnake(semilla: 1);
      // Se pone la comida justo delante de la cabeza.
      final cabeza = j.cuerpo.first;
      j.comida = Point(cabeza.x + 1, cabeza.y);
      final largoAntes = j.largo;

      j.avanzar();

      expect(j.puntaje, greaterThan(0));
      expect(j.largo, largoAntes + 1);
      expect(j.comida, isNot(Point(cabeza.x + 1, cabeza.y)));
    });

    test('chocar contra la pared termina el juego', () {
      final j = JuegoSnake(semilla: 1);
      // Se la lleva hasta el borde derecho.
      for (var i = 0; i < JuegoSnake.columnas + 2; i++) {
        j.comida = const Point(-1, -1); // fuera del tablero: nunca come
        j.avanzar();
        if (j.terminado) break;
      }
      expect(j.terminado, isTrue);
    });

    test('ir derecho no la hace chocar contra su propia cola', () {
      final j = JuegoSnake(semilla: 1);
      j.comida = const Point(-1, -1);
      for (var i = 0; i < 4; i++) {
        j.avanzar();
      }
      expect(j.terminado, isFalse);
    });

    test('morderse a sí misma termina el juego', () {
      final j = JuegoSnake(semilla: 1);
      j.comida = const Point(-1, -1);
      // Con un cuerpo largo, un cuadrado cerrado la hace pisarse.
      final cabeza = j.cuerpo.first;
      j.cuerpo = [
        cabeza,
        Point(cabeza.x - 1, cabeza.y),
        Point(cabeza.x - 1, cabeza.y + 1),
        Point(cabeza.x, cabeza.y + 1),
        Point(cabeza.x + 1, cabeza.y + 1),
      ];
      j.girar(Direccion.abajo);
      j.avanzar();
      expect(j.terminado, isTrue);
    });

    test('acelera al subir de nivel', () {
      final j = JuegoSnake(semilla: 1);
      final intervaloInicial = j.intervalo;
      j.nivel = 5;
      expect(j.intervalo, lessThan(intervaloInicial));
    });

    test('la vista marca cabeza, cuerpo y comida por separado', () {
      final j = JuegoSnake(semilla: 1);
      final v = j.vista(colorCabeza: 1, colorCuerpo: 2, colorComida: 3);
      expect(v.length, JuegoSnake.filas);
      expect(v[0].length, JuegoSnake.columnas);
      expect(v.expand((f) => f).where((c) => c == 1).length, 1);
      expect(v.expand((f) => f).where((c) => c == 2).length,
          JuegoSnake.largoInicial - 1);
      expect(v.expand((f) => f).where((c) => c == 3).length, 1);
    });

    test('un juego terminado ya no se mueve', () {
      final j = JuegoSnake(semilla: 1);
      j.terminado = true;
      final cabezaAntes = j.cuerpo.first;
      j.avanzar();
      expect(j.cuerpo.first, cabezaAntes);
    });

    test('reiniciar deja todo como al principio', () {
      final j = JuegoSnake(semilla: 1);
      j.puntaje = 300;
      j.terminado = true;
      j.reiniciar();
      expect(j.puntaje, 0);
      expect(j.terminado, isFalse);
      expect(j.largo, JuegoSnake.largoInicial);
      expect(j.direccion, Direccion.derecha);
    });
  });
}
