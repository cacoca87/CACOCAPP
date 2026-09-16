import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/bibliotecas_reservadas.dart';

void main() {
  group('errorDeNombreDeBiblioteca', () {
    test('un nombre libre está bien', () {
      expect(
        errorDeNombreDeBiblioteca('Para manejar',
            nombresExistentes: const ['Rock', 'Salsa']),
        isNull,
      );
    });

    test('vacío o solo espacios no sirve', () {
      expect(
        errorDeNombreDeBiblioteca('', nombresExistentes: const []),
        contains('Escribí un nombre'),
      );
      expect(
        errorDeNombreDeBiblioteca('   ', nombresExistentes: const []),
        contains('Escribí un nombre'),
      );
    });

    test('los cuatro nombres de la app están reservados', () {
      // "Recientes" y "Más Escuchadas" son los que faltaban: una
      // playlist con ese nombre quedaba tapada por la vista del mismo
      // nombre y no se podía abrir nunca más.
      for (final reservado in nombresReservadosDeBiblioteca) {
        expect(
          errorDeNombreDeBiblioteca(reservado, nombresExistentes: const []),
          contains('reservado'),
          reason: reservado,
        );
      }
    });

    test('no se puede repetir una que ya existe', () {
      expect(
        errorDeNombreDeBiblioteca('Rock', nombresExistentes: const ['Rock']),
        contains('Ya tenés'),
      );
    });

    test('al renombrar, su propio nombre no cuenta como repetido', () {
      expect(
        errorDeNombreDeBiblioteca(
          'Rock',
          nombresExistentes: const ['Rock', 'Salsa'],
          nombreQueSeReemplaza: 'Rock',
        ),
        isNull,
      );
    });

    test('los espacios de los costados no cambian el resultado', () {
      expect(
        errorDeNombreDeBiblioteca('  Favoritos  ',
            nombresExistentes: const []),
        contains('reservado'),
      );
    });
  });
}
