import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CACOCAPP/utils/records_juegos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('leerRecord', () {
    test('sin nada guardado devuelve cero', () async {
      expect(await leerRecord('tetris_record_v1'), 0);
    });

    test('devuelve lo que hay guardado', () async {
      SharedPreferences.setMockInitialValues({'tetris_record_v1': 4200});
      expect(await leerRecord('tetris_record_v1'), 4200);
    });

    test('cada juego tiene su propio récord', () async {
      SharedPreferences.setMockInitialValues({
        'tetris_record_v1': 4200,
        'snake_record_v1': 90,
      });
      expect(await leerRecord('tetris_record_v1'), 4200);
      expect(await leerRecord('snake_record_v1'), 90);
      expect(await leerRecord('carrera_record_v1'), 0);
    });
  });

  group('guardarRecordSiEsMejor', () {
    test('el primer puntaje se guarda', () async {
      expect(await guardarRecordSiEsMejor('carrera_record_v1', 30), 30);
      expect(await leerRecord('carrera_record_v1'), 30);
    });

    test('un puntaje mejor reemplaza al anterior', () async {
      SharedPreferences.setMockInitialValues({'carrera_record_v1': 30});
      expect(await guardarRecordSiEsMejor('carrera_record_v1', 80), 80);
      expect(await leerRecord('carrera_record_v1'), 80);
    });

    test('EL CASO QUE IMPORTA: una partida mala no borra el récord', () async {
      // Esto es lo que pasaba de verdad. El récord se lee del disco al
      // abrir el juego y esa lectura tarda; si perdías antes de que
      // terminara, la pantalla todavía creía que el récord era 0 y
      // escribía el puntaje nuevo encima del bueno.
      //
      // Comparando contra el disco, el récord viejo sobrevive aunque
      // quien llame no lo conozca todavía.
      SharedPreferences.setMockInitialValues({'disparos_record_v1': 500});
      expect(await guardarRecordSiEsMejor('disparos_record_v1', 20), 500);
      expect(await leerRecord('disparos_record_v1'), 500);
    });

    test('empatar el récord no cuenta como récord nuevo', () async {
      // El cartel dice "¡Nuevo récord!" solo si de verdad lo superaste.
      SharedPreferences.setMockInitialValues({'snake_record_v1': 120});
      expect(await guardarRecordSiEsMejor('snake_record_v1', 120), 120);
    });

    test('devuelve el récord vigente para que la pantalla se corrija',
        () async {
      // La pantalla mostraba 0 porque la lectura no había llegado; con
      // lo que devuelve esto puede mostrar el número correcto.
      SharedPreferences.setMockInitialValues({'tetris_record_v1': 9000});
      final vigente = await guardarRecordSiEsMejor('tetris_record_v1', 10);
      expect(vigente, 9000);
    });

    test('un cero no pisa nada', () async {
      SharedPreferences.setMockInitialValues({'snake_record_v1': 70});
      expect(await guardarRecordSiEsMejor('snake_record_v1', 0), 70);
      expect(await leerRecord('snake_record_v1'), 70);
    });
  });
}
