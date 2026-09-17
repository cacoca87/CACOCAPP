import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/busqueda.dart';

void main() {
  group('paraBuscar', () {
    test('saca las tildes', () {
      expect(paraBuscar('Corazón'), 'corazon');
      expect(paraBuscar('Amén'), 'amen');
      expect(paraBuscar('El Niño'), 'el nino');
      expect(paraBuscar('Mägo de Oz'), 'mago de oz');
    });

    test('deja igual lo que no tiene nada raro', () {
      expect(paraBuscar('Soda Stereo'), 'soda stereo');
      expect(paraBuscar(''), '');
    });

    test('no se come los números ni los signos', () {
      // Hay discos que se llaman así, y perderlos sería peor que las
      // tildes.
      expect(paraBuscar('24/7'), '24/7');
      expect(paraBuscar('¿Dónde están?'), '¿donde estan?');
    });

    test('las dos tablas de letras están alineadas', () {
      // Si una tuviera una letra de más, TODAS las de esa letra en
      // adelante se traducirían mal y en silencio. Se comprueba de
      // punta a punta: cada letra con marca se convierte en una sola
      // letra sin marca.
      const conMarca = 'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
      for (final letra in conMarca.split('')) {
        final convertida = paraBuscar(letra);
        expect(convertida.length, 1,
            reason: '"$letra" no se convirtió en una sola letra');
        expect(RegExp(r'^[a-z]$').hasMatch(convertida), isTrue,
            reason: '"$letra" se convirtió en "$convertida"');
      }
    });
  });

  group('coincideLaBusqueda', () {
    const campos = ['Corazón Delator', 'Soda Stereo', 'Signos'];

    test('encuentra aunque no escribas la tilde', () {
      // Es el motivo por el que existe todo esto: en el teclado del
      // celular la tilde cuesta, así que nadie la escribe al buscar.
      expect(coincideLaBusqueda('corazon', campos), isTrue);
      expect(coincideLaBusqueda('CORAZON', campos), isTrue);
    });

    test('encuentra igual si SÍ escribís la tilde', () {
      expect(coincideLaBusqueda('corazón', campos), isTrue);
    });

    test('busca en el título, en el artista y en el álbum', () {
      expect(coincideLaBusqueda('delator', campos), isTrue);
      expect(coincideLaBusqueda('stereo', campos), isTrue);
      expect(coincideLaBusqueda('signos', campos), isTrue);
    });

    test('el orden de las palabras no importa', () {
      expect(coincideLaBusqueda('stereo soda', campos), isTrue);
      expect(coincideLaBusqueda('signos corazon', campos), isTrue);
    });

    test('tienen que estar TODAS las palabras', () {
      expect(coincideLaBusqueda('soda charly', campos), isFalse);
    });

    test('lo que no está, no aparece', () {
      expect(coincideLaBusqueda('metallica', campos), isFalse);
    });

    test('una búsqueda vacía o de puros espacios encuentra todo', () {
      expect(coincideLaBusqueda('', campos), isTrue);
      expect(coincideLaBusqueda('   ', campos), isTrue);
    });

    test('los espacios de más no molestan', () {
      expect(coincideLaBusqueda('  soda   stereo  ', campos), isTrue);
    });

    test('un campo vacío no rompe nada', () {
      // Pasa de verdad: muchos MP3 no traen álbum.
      expect(coincideLaBusqueda('nada', const ['', '', '']), isFalse);
      expect(coincideLaBusqueda('', const ['', '', '']), isTrue);
    });

    test('sigue encontrando pedazos de palabra', () {
      // Lo que ya hacía antes tiene que seguir andando: se escribe de a
      // poco y los resultados se van filtrando con cada letra.
      expect(coincideLaBusqueda('cora', campos), isTrue);
      expect(coincideLaBusqueda('ster', campos), isTrue);
    });
  });

  group('nombresOrdenados', () {
    test('"Ángel" va donde corresponde, no al final', () {
      // Esto es lo que estaba mal en las grillas de Artistas y Álbumes:
      // ordenando por el texto crudo, la "Á" cae DESPUÉS de la "Z".
      final ordenados = nombresOrdenados(['Zeta Bosio', 'Ángel', 'Charly']);
      expect(ordenados, ['Ángel', 'Charly', 'Zeta Bosio']);
    });

    test('no le importan las mayúsculas', () {
      expect(nombresOrdenados(['soda', 'Amén', 'ZZ Top']),
          ['Amén', 'soda', 'ZZ Top']);
    });

    test('saca los repetidos', () {
      expect(nombresOrdenados(['Soda', 'Soda', 'Soda']), ['Soda']);
    });

    test('saca los vacíos y los de puros espacios', () {
      // Un álbum vacío armaba una tarjeta sin nombre en la grilla. Pasa
      // con los MP3 que no traen el dato, que son muchos --y más desde
      // que la app lee la música del propio celular--.
      expect(nombresOrdenados(['', '   ', 'Signos']), ['Signos']);
      expect(nombresOrdenados(['', '']), isEmpty);
    });

    test('NO recorta los espacios: devuelve el nombre tal cual vino', () {
      // Parece una mejora recortarlos, y rompe la app: al tocar la
      // tarjeta se buscan las canciones cuyo artista sea EXACTAMENTE
      // ese texto. Recortado no coincidiría con ninguna y la tarjeta
      // abriría una lista vacía.
      expect(nombresOrdenados(['  Soda  ']), ['  Soda  ']);
    });

    test('dos que solo se diferencian en la tilde no se pisan', () {
      // Y el orden entre ellos es siempre el mismo, no depende de cuál
      // se leyó primero.
      expect(nombresOrdenados(['Amen', 'Amén']),
          nombresOrdenados(['Amén', 'Amen']));
      expect(nombresOrdenados(['Amen', 'Amén']).length, 2);
    });

    test('una lista vacía da una lista vacía', () {
      expect(nombresOrdenados(const []), isEmpty);
    });
  });
}
