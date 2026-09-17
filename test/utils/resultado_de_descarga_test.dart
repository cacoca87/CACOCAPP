import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/resultado_de_descarga.dart';

void main() {
  group('mensajeDeDescarga', () {
    test('cada motivo dice algo DISTINTO', () {
      // Es el punto de todo esto. Antes tres fallos muy distintos
      // --sin señal, el servidor no tiene la canción, no queda espacio
      // en el celular-- mostraban el mismo cartel: "revisá tu
      // conexión". Los dos últimos mandaban a la persona a mirar el
      // wifi cuando el problema estaba en otro lado.
      final mensajes = ResultadoDeDescarga.values
          .map((r) => mensajeDeDescarga(r, 'Roxanne'))
          .toSet();
      expect(mensajes.length, ResultadoDeDescarga.values.length);
    });

    test('todos nombran la canción', () {
      for (final r in ResultadoDeDescarga.values) {
        expect(mensajeDeDescarga(r, 'Roxanne'), contains('Roxanne'),
            reason: '$r no dice de qué canción habla');
      }
    });

    test('solo el de verdad sin señal manda a revisar la conexión', () {
      // Lo que no puede pasar es que un mensaje mande a mirar el wifi
      // cuando el problema está en otro lado. Nombrar la conexión para
      // DESCARTARLA sí vale --el del servidor dice "No es tu
      // conexión"--, así que lo que se busca es la orden, no la
      // palabra.
      expect(mensajeDeDescarga(ResultadoDeDescarga.sinConexion, 'x'),
          contains('Revisá tu conexión'));

      for (final r in ResultadoDeDescarga.values) {
        if (r == ResultadoDeDescarga.sinConexion) continue;
        expect(mensajeDeDescarga(r, 'x').toLowerCase(),
            isNot(contains('revisá tu conexión')),
            reason: '$r manda a revisar la conexión sin motivo');
      }
    });

    test('el del servidor aclara que NO es tu conexión', () {
      // Sin esa aclaración, la persona igual va a mirar el wifi.
      expect(
        mensajeDeDescarga(ResultadoDeDescarga.noEstaEnElServidor, 'x'),
        contains('No es tu conexión'),
      );
    });

    test('el de espacio habla de espacio', () {
      expect(
        mensajeDeDescarga(ResultadoDeDescarga.noEntraEnElCelular, 'x'),
        contains('espacio'),
      );
    });
  });

  group('esUnFallo', () {
    test('los tres fallos son fallos', () {
      expect(esUnFallo(ResultadoDeDescarga.sinConexion), isTrue);
      expect(esUnFallo(ResultadoDeDescarga.noEstaEnElServidor), isTrue);
      expect(esUnFallo(ResultadoDeDescarga.noEntraEnElCelular), isTrue);
    });

    test('que ya estuviera descargada NO es un fallo', () {
      // Se pintaba de rojo como si algo hubiera salido mal, y la
      // canción estaba perfectamente guardada.
      expect(esUnFallo(ResultadoDeDescarga.lista), isFalse);
      expect(esUnFallo(ResultadoDeDescarga.yaEstaba), isFalse);
      expect(esUnFallo(ResultadoDeDescarga.yaSeEstaBajando), isFalse);
    });
  });
}
