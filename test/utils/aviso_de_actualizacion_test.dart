import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/aviso_de_actualizacion.dart';

void main() {
  group('avisoDeActualizacion', () {
    test('todo bien y sin música del celular', () {
      expect(
        avisoDeActualizacion(
            vinoDelServidor: true,
            delServidor: 160,
            delCelular: 0,
            salteados: 0),
        'Biblioteca actualizada: 160 canciones',
      );
    });

    test('con música del celular', () {
      expect(
        avisoDeActualizacion(
            vinoDelServidor: true,
            delServidor: 160,
            delCelular: 23,
            salteados: 0),
        'Biblioteca actualizada: 160 canciones · 23 canciones del celular',
      );
    });

    test('con música del celular y archivos salteados', () {
      expect(
        avisoDeActualizacion(
            vinoDelServidor: true,
            delServidor: 160,
            delCelular: 23,
            salteados: 47),
        'Biblioteca actualizada: 160 canciones · 23 canciones del celular '
        '(se saltearon 47 que no son música)',
      );
    });

    test('el peor caso: el filtro se llevó puesto TODO', () {
      // Es el que faltaba. Antes, con cero canciones del celular el
      // aviso no decía nada --ni siquiera cuántas se habían salteado--,
      // justo cuando más falta hace saberlo: si el filtro se comió toda
      // tu música, la app se quedaba callada y parecía que no había
      // nada en el teléfono.
      final texto = avisoDeActualizacion(
          vinoDelServidor: true,
          delServidor: 160,
          delCelular: 0,
          salteados: 47);
      expect(texto, contains('ninguna del celular'));
      expect(texto, contains('47'));
    });

    test('el servidor no contestó', () {
      final texto = avisoDeActualizacion(
          vinoDelServidor: false,
          delServidor: 160,
          delCelular: 0,
          salteados: 0);
      expect(texto, contains('No se pudo consultar el servidor'));
      expect(texto, contains('160 canciones'));
    });

    test('el servidor no contestó y además hay música del celular', () {
      final texto = avisoDeActualizacion(
          vinoDelServidor: false,
          delServidor: 160,
          delCelular: 5,
          salteados: 2);
      expect(texto, contains('No se pudo consultar el servidor'));
      expect(texto, contains('5 canciones del celular'));
      expect(texto, contains('2 que no son música'));
    });

    test('una sola canción va en singular', () {
      expect(
        avisoDeActualizacion(
            vinoDelServidor: true,
            delServidor: 1,
            delCelular: 1,
            salteados: 0),
        'Biblioteca actualizada: 1 canción · 1 canción del celular',
      );
    });

    test('la biblioteca vacía no rompe el texto', () {
      expect(
        avisoDeActualizacion(
            vinoDelServidor: true,
            delServidor: 0,
            delCelular: 0,
            salteados: 0),
        'Biblioteca actualizada: 0 canciones',
      );
    });
  });
}
