import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/formato_tiempo.dart';

void main() {
  group('duracionCorta', () {
    test('una canción normal', () {
      expect(duracionCorta(const Duration(minutes: 3, seconds: 5)), '3:05');
      expect(duracionCorta(const Duration(minutes: 12, seconds: 45)), '12:45');
    });

    test('rellena los segundos con cero', () {
      expect(duracionCorta(const Duration(seconds: 7)), '0:07');
    });

    test('pasando la hora, la hora aparece', () {
      // Este es el bug que tenía el reproductor: con
      // `inMinutes.remainder(60)` esto se mostraba como "05:30" y la
      // hora entera desaparecía.
      expect(
        duracionCorta(const Duration(hours: 1, minutes: 5, seconds: 30)),
        '1:05:30',
      );
      expect(duracionCorta(const Duration(hours: 2)), '2:00:00');
    });

    test('cero y negativos no rompen', () {
      expect(duracionCorta(Duration.zero), '0:00');
      expect(duracionCorta(const Duration(seconds: -5)), '0:00');
    });
  });

  group('tiempoEscuchado', () {
    test('menos de un minuto se cuenta en segundos', () {
      // Antes esto decía "0 min", que parece un error y no un dato.
      expect(tiempoEscuchado(30), '30 s');
      expect(tiempoEscuchado(0), '0 s');
    });

    test('minutos y horas', () {
      expect(tiempoEscuchado(60), '1 min');
      expect(tiempoEscuchado(2700), '45 min');
      expect(tiempoEscuchado(7500), '2 h 5 min');
    });
  });

  group('tiempoEscuchadoCorto', () {
    test('la versión que entra en el eje del gráfico', () {
      expect(tiempoEscuchadoCorto(30), '30s');
      expect(tiempoEscuchadoCorto(2700), '45m');
      expect(tiempoEscuchadoCorto(7500), '2h 5m');
    });
  });
}
