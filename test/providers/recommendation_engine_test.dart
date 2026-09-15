import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/models/song.dart';
import 'package:CACOCAPP/providers/recommendation_engine.dart';

Song _song(String id) => Song(id: id, title: id, artist: 'Artista', album: 'Album', url: 'x', coverUrl: '');

void main() {
  group('calcularRecomendaciones', () {
    test('devuelve vacío si no hay canciones', () {
      expect(calcularRecomendaciones([], []), isEmpty);
    });

    test('prioriza las canciones que no están en el historial', () {
      final todas = [_song('a'), _song('b'), _song('c')];
      final resultado = calcularRecomendaciones(todas, ['a', 'b']);

      expect(resultado.map((s) => s.id), everyElement('c'));
    });

    test('si ya se escuchó todo, cae de nuevo sobre toda la biblioteca (no devuelve vacío)', () {
      final todas = [_song('a'), _song('b'), _song('c')];
      final resultado = calcularRecomendaciones(todas, ['a', 'b', 'c']);

      expect(resultado, isNotEmpty);
      expect(resultado.map((s) => s.id).toSet(), {'a', 'b', 'c'});
    });

    test('respeta el límite de cantidad pedido', () {
      final todas = List.generate(20, (i) => _song('s$i'));
      final resultado = calcularRecomendaciones(todas, [], cantidad: 5);

      expect(resultado.length, 5);
    });

    test('no devuelve más elementos que los disponibles', () {
      final todas = [_song('a'), _song('b')];
      final resultado = calcularRecomendaciones(todas, [], cantidad: 10);

      expect(resultado.length, 2);
    });

    test('no repite canciones en el resultado', () {
      final todas = List.generate(15, (i) => _song('s$i'));
      final resultado = calcularRecomendaciones(todas, []);

      expect(resultado.map((s) => s.id).toSet().length, resultado.length);
    });
  });

  group('ordenarPorMasEscuchadas', () {
    test('ordena de más a menos reproducciones', () {
      final conteo = {'a': 3, 'b': 10, 'c': 1};
      expect(ordenarPorMasEscuchadas(conteo), ['b', 'a', 'c']);
    });

    test('devuelve vacío si no hay conteo', () {
      expect(ordenarPorMasEscuchadas({}), isEmpty);
    });

    test('con un solo elemento, lo devuelve solo', () {
      expect(ordenarPorMasEscuchadas({'unica': 5}), ['unica']);
    });
  });
}
