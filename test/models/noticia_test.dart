import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/models/noticia.dart';

/// El texto que va al lado de la fuente en cada noticia: "hace 3 h".
///
/// Se prefiere eso a la fecha exacta porque en noticias lo que importa
/// es qué tan reciente es. Hasta ahora no se podía probar: la cuenta
/// usaba `DateTime.now()` por dentro, así que un test tendría que
/// esperar horas de verdad.

final _ahora = DateTime(2026, 9, 17, 12, 0);

Noticia _hace(Duration d) => Noticia(
      titulo: 'Algo pasó',
      enlace: 'https://ejemplo.test/n',
      fuente: 'El Comercio',
      fecha: _ahora.subtract(d),
    );

void main() {
  group('antigüedad de una noticia', () {
    test('recién publicada', () {
      expect(_hace(const Duration(seconds: 20)).antiguedadDesde(_ahora),
          'recién');
    });

    test('minutos', () {
      expect(_hace(const Duration(minutes: 1)).antiguedadDesde(_ahora),
          'hace 1 min');
      expect(_hace(const Duration(minutes: 45)).antiguedadDesde(_ahora),
          'hace 45 min');
    });

    test('horas', () {
      expect(
          _hace(const Duration(hours: 3)).antiguedadDesde(_ahora), 'hace 3 h');
      expect(_hace(const Duration(hours: 23)).antiguedadDesde(_ahora),
          'hace 23 h');
    });

    test('ayer', () {
      expect(_hace(const Duration(hours: 25)).antiguedadDesde(_ahora), 'ayer');
    });

    test('días', () {
      expect(_hace(const Duration(days: 3)).antiguedadDesde(_ahora),
          'hace 3 días');
    });

    test('más de un mes se cuenta en meses', () {
      // "hace 213 días" no se lee: se calcula.
      expect(_hace(const Duration(days: 31)).antiguedadDesde(_ahora),
          'hace un mes');
      expect(_hace(const Duration(days: 213)).antiguedadDesde(_ahora),
          'hace 7 meses');
    });

    test('los bordes caen del lado correcto', () {
      // Justo en el cambio de unidad es donde se cuelan los "hace 60
      // min" y los "hace 24 h".
      expect(_hace(const Duration(minutes: 59)).antiguedadDesde(_ahora),
          'hace 59 min');
      expect(
          _hace(const Duration(minutes: 60)).antiguedadDesde(_ahora),
          'hace 1 h');
      expect(_hace(const Duration(hours: 24)).antiguedadDesde(_ahora), 'ayer');
      expect(_hace(const Duration(hours: 48)).antiguedadDesde(_ahora),
          'hace 2 días');
    });

    test('una noticia del futuro no dice "hace -2 h"', () {
      // Pasa de verdad: el reloj del celular puede estar atrasado
      // respecto del servidor.
      final futura = Noticia(
        titulo: 'x',
        enlace: 'x',
        fuente: 'x',
        fecha: _ahora.add(const Duration(hours: 2)),
      );
      expect(futura.antiguedadDesde(_ahora), 'recién');
    });

    test('sin fecha no se inventa nada', () {
      // Google News a veces no la manda, y el texto se une con " · ":
      // un valor cualquiera dejaría un punto suelto colgando.
      const sinFecha =
          Noticia(titulo: 'x', enlace: 'x', fuente: 'El Comercio');
      expect(sinFecha.antiguedadDesde(_ahora), '');
    });

    test('nunca dice un número negativo', () {
      final casos = [
        const Duration(hours: -100),
        const Duration(seconds: -1),
        Duration.zero,
        const Duration(days: 1000),
      ];
      for (final d in casos) {
        final texto = _hace(d).antiguedadDesde(_ahora);
        expect(texto, isNot(contains('-')), reason: 'con $d dijo "$texto"');
      }
    });
  });
}
