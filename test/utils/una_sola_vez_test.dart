import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/una_sola_vez.dart';

void main() {
  group('UnaSolaVez', () {
    test('dos pedidos iguales a la vez hacen el trabajo UNA vez', () async {
      var veces = 0;
      final guardia = UnaSolaVez<String>();

      Future<String> trabajo() async {
        veces++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 'listo';
      }

      final resultados = await Future.wait([
        guardia.hacer('a', trabajo),
        guardia.hacer('a', trabajo),
        guardia.hacer('a', trabajo),
      ]);

      expect(veces, 1);
      expect(resultados, ['listo', 'listo', 'listo']);
    });

    test('claves distintas no se estorban', () async {
      var veces = 0;
      final guardia = UnaSolaVez<String>();
      Future<String> trabajo() async {
        veces++;
        return 'x';
      }

      await Future.wait([
        guardia.hacer('a', trabajo),
        guardia.hacer('b', trabajo),
      ]);
      expect(veces, 2);
    });

    test('terminado, el próximo pedido vuelve a trabajar', () async {
      // No es un caché: si el resultado hay que recordarlo, eso es
      // tarea de quien llama. Acá solo se junta lo simultáneo.
      var veces = 0;
      final guardia = UnaSolaVez<String>();
      Future<String> trabajo() async {
        veces++;
        return 'x';
      }

      await guardia.hacer('a', trabajo);
      await guardia.hacer('a', trabajo);
      expect(veces, 2);
    });

    test('si falla, la anotación no queda trabada', () async {
      // Lo importante: un fallo (quedarse sin red, por ejemplo) no
      // puede dejar esa clave bloqueada para el resto de la sesión.
      final guardia = UnaSolaVez<String>();

      await expectLater(
        guardia.hacer('a', () async => throw StateError('sin red')),
        throwsStateError,
      );
      expect(guardia.enCurso, 0);

      expect(await guardia.hacer('a', () async => 'ahora sí'), 'ahora sí');
    });

    test('un trabajo que explota en el acto tampoco la traba', () async {
      // Una función marcada `async` devuelve su error por la promesa,
      // pero una que NO lo esté lanza en el acto, antes de devolver
      // nada. Sin el `Future.sync` de adentro, ese caso se saltaba la
      // limpieza y la clave quedaba trabada para el resto de la sesión.
      //
      // Con él, el fallo viaja por la promesa como cualquier otro: se
      // puede atrapar donde corresponde y la clave queda libre.
      final guardia = UnaSolaVez<String>();

      await expectLater(
        guardia.hacer('a', () => throw StateError('explotó')),
        throwsStateError,
      );
      expect(guardia.enCurso, 0);

      expect(await guardia.hacer('a', () async => 'ahora sí'), 'ahora sí');
    });

    test('todos reciben el mismo fallo, no solo el primero', () async {
      final guardia = UnaSolaVez<String>();
      Future<String> trabajo() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        throw StateError('sin red');
      }

      final a = guardia.hacer('a', trabajo);
      final b = guardia.hacer('a', trabajo);
      await expectLater(a, throwsStateError);
      await expectLater(b, throwsStateError);
    });
  });
}
