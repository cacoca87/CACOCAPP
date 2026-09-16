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
}
