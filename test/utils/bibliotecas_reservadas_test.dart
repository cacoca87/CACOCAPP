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
        errorDeNombreDeBiblioteca('  Favoritos  ', nombresExistentes: const []),
        contains('reservado'),
      );
    });

    group('las mayúsculas y las tildes tampoco', () {
      // Antes se comparaba letra por letra, así que estos pasaban. El
      // resultado era una playlist llamada "favoritos" al lado de la
      // vista "Favoritos" de la app, o "Mas Escuchadas" sin tilde al
      // lado de "Más Escuchadas": dos entradas que parecen la misma y
      // no lo son.
      const variantes = [
        'favoritos',
        'FAVORITOS',
        'FaVoRiToS',
        'Mas Escuchadas', // sin tilde
        'mas escuchadas',
        'toda tu musica', // sin tilde y en minúsculas
      ];

      for (final nombre in variantes) {
        test('"$nombre" sigue siendo un nombre reservado', () {
          expect(
            errorDeNombreDeBiblioteca(nombre, nombresExistentes: const []),
            contains('reservado'),
          );
        });
      }

      test('dos playlists tuyas que solo difieren en mayúsculas chocan', () {
        // Si no, terminás con "Rock" y "rock" en la barra lateral y las
        // canciones repartidas entre las dos sin entender por qué.
        expect(
          errorDeNombreDeBiblioteca('rock', nombresExistentes: const ['Rock']),
          contains('Ya tenés'),
        );
        expect(
          errorDeNombreDeBiblioteca('Cumbia',
              nombresExistentes: const ['cumbiá']),
          contains('Ya tenés'),
        );
      });

      test('cambiarle SOLO las mayúsculas a una playlist sigue valiendo', () {
        // Renombrar "Rock" a "rock" no puede chocar consigo misma.
        expect(
          errorDeNombreDeBiblioteca(
            'rock',
            nombresExistentes: const ['Rock'],
            nombreQueSeReemplaza: 'Rock',
          ),
          isNull,
        );
      });

      test('un nombre distinto de verdad sigue estando libre', () {
        expect(
          errorDeNombreDeBiblioteca('Favoritas del verano',
              nombresExistentes: const ['Rock']),
          isNull,
        );
      });
    });
  });
}
