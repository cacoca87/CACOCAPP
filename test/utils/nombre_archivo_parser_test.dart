import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/nombre_archivo_parser.dart';

const _artistasQueVanPrimero = [
  'Bruce Springsteen',
  'Dire Straits',
  'Los Pericos',
  'Marc Anthony',
  'Metallica',
  'The Traveling Wilburys Collection',
];

TituloYArtista _parsear(String nombre) => deducirTituloYArtista(
      nombre,
      artistasQueVanPrimero: _artistasQueVanPrimero,
    );

void main() {
  group('deducirTituloYArtista', () {
    test('sin separador deja el nombre como título y el artista sin saber', () {
      final r = _parsear("Runnin' Down A Dream");
      expect(r.titulo, "Runnin' Down A Dream");
      expect(r.artista, artistaDesconocido);
    });

    test('dos partes: "Título - Artista"', () {
      final r = _parsear('A Kind Of Magic - Queen');
      expect(r.titulo, 'A Kind Of Magic');
      expect(r.artista, 'Queen');
    });

    test('artista de la lista que va primero, se invierte', () {
      final r = _parsear('Metallica - Enter Sandman');
      expect(r.titulo, 'Enter Sandman');
      expect(r.artista, 'Metallica');
    });

    test('el artista que va primero conserva los guiones del título', () {
      final r = _parsear('Dire Straits - Money For Nothing - Live');
      expect(r.titulo, 'Money For Nothing - Live');
      expect(r.artista, 'Dire Straits');
    });

    group('regresión: un calificador de versión no puede ser el artista', () {
      test('calificador en el medio (antes daba artista "Remaster")', () {
        final r = _parsear('Black Dog - Remaster - Led Zeppelin');
        expect(r.titulo, 'Black Dog');
        expect(r.artista, 'Led Zeppelin');
      });

      test('otro caso real de la biblioteca', () {
        final r = _parsear('Ramble On - Remaster - Led Zeppelin');
        expect(r.artista, 'Led Zeppelin');
      });

      test('calificador al final, el artista ya estaba bien', () {
        final r = _parsear('Immigrant Song - Led Zeppelin - Remaster');
        expect(r.titulo, 'Immigrant Song');
        expect(r.artista, 'Led Zeppelin');
      });

      test('calificador con año delante', () {
        final r = _parsear('Five Years - David Bowie - 2012 Remaster');
        expect(r.artista, 'David Bowie');
      });

      test('calificador con año detrás', () {
        final r = _parsear('Some Song - Remaster 2009 - Pink Floyd');
        expect(r.artista, 'Pink Floyd');
      });

      test('si TODO lo que sigue son calificadores, no inventa un artista', () {
        final r = _parsear('Ziggy Stardust - 2012 Remaster');
        expect(r.titulo, 'Ziggy Stardust');
        expect(r.artista, artistaDesconocido);
      });
    });

    test('un artista real que contiene un año no se confunde con versión', () {
      final r = _parsear('Song - Blink 182');
      expect(r.artista, 'Blink 182');
    });
  });

  group('tituloSabiendoElArtista', () {
    test('el caso real: "Amén - Te Quiero" con artista "Amén"', () {
      // La app mostraba tres canciones distintas del disco "Libre",
      // las tres tituladas "Amén", que es el nombre de la banda.
      expect(tituloSabiendoElArtista('Amén - Te Quiero', 'Amén'), 'Te Quiero');
      expect(
        tituloSabiendoElArtista('Amén - Sé Que Tú No Estás Solo', 'Amén'),
        'Sé Que Tú No Estás Solo',
      );
    });

    test('si el archivo ya estaba bien, no lo toca', () {
      // "Título - Artista", que es lo habitual en esta biblioteca.
      expect(
        tituloSabiendoElArtista(
            'Whole Lotta Love - Led Zeppelin', 'Led Zeppelin'),
        isNull,
      );
    });

    test('no distingue mayúsculas ni espacios de sobra', () {
      expect(tituloSabiendoElArtista('  AMÉN  -  Libre  ', 'amén'), 'Libre');
    });

    test('un título con guiones adentro se conserva entero', () {
      expect(
        tituloSabiendoElArtista('Amén - Yo - Tú - Nosotros', 'Amén'),
        'Yo - Tú - Nosotros',
      );
    });

    test('sin guion, sin artista o sin nombre no hay nada que corregir', () {
      expect(tituloSabiendoElArtista('Amén', 'Amén'), isNull);
      expect(tituloSabiendoElArtista('Amén - Libre', ''), isNull);
      expect(tituloSabiendoElArtista('', 'Amén'), isNull);
    });

    test('un archivo que es solo "Artista - " no deja el título vacío', () {
      expect(tituloSabiendoElArtista('Amén - ', 'Amén'), isNull);
    });
  });

  group('nombreDeArchivoDeUrl', () {
    test('saca la carpeta, la extensión y los códigos de la URL', () {
      expect(
        nombreDeArchivoDeUrl(
            'https://ejemplo.test/Am%C3%A9n%20-%20Te%20Quiero.mp3'),
        'Amén - Te Quiero',
      );
    });

    test('aguanta una ruta local o algo que no sea una URL', () {
      expect(nombreDeArchivoDeUrl('Whole Lotta Love.mp3'), 'Whole Lotta Love');
    });
  });
}
