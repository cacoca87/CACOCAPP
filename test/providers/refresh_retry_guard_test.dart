import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/providers/refresh_retry_guard.dart';

void main() {
  group('RefreshRetryGuard', () {
    test('permite reintentar hasta agotar el máximo de intentos', () {
      final guard = RefreshRetryGuard(maxIntentos: 3);

      expect(guard.deberiaReintentar('yt_a'), isTrue); // intento 1
      expect(guard.deberiaReintentar('yt_a'), isTrue); // intento 2
      expect(guard.deberiaReintentar('yt_a'), isTrue); // intento 3
      expect(guard.deberiaReintentar('yt_a'), isFalse); // ya no queda presupuesto
      expect(guard.deberiaReintentar('yt_a'), isFalse); // sigue sin permitir -- no crece infinito
    });

    test(
      'regresión del bug real: dos canciones que fallan alternadamente no se pisan el presupuesto entre sí',
      () {
        // Esto es exactamente lo que pasó en la práctica (CAMBIOS.md,
        // sección 29): "Lethal Industry" y "Don't Be Shy" fallando y
        // alternándose -- sin este comportamiento, cada cambio de
        // canción reseteaba el contador de la otra y el bucle nunca
        // se cortaba.
        final guard = RefreshRetryGuard(maxIntentos: 3);

        expect(guard.deberiaReintentar('yt_lethal_industry'), isTrue);
        expect(guard.deberiaReintentar('yt_dont_be_shy'), isTrue); // cambia de canción
        expect(guard.intentosPara('yt_lethal_industry'), 0); // se resetea al cambiar
        expect(guard.intentosPara('yt_dont_be_shy'), 1);

        expect(guard.deberiaReintentar('yt_lethal_industry'), isTrue); // arranca de nuevo, no arrastra nada
        expect(guard.intentosPara('yt_lethal_industry'), 1);
      },
    );

    test('reset() deja presupuesto fresco para la misma canción', () {
      final guard = RefreshRetryGuard(maxIntentos: 2);
      guard.deberiaReintentar('yt_x');
      guard.deberiaReintentar('yt_x');
      expect(guard.deberiaReintentar('yt_x'), isFalse); // agotado

      guard.reset();

      expect(guard.deberiaReintentar('yt_x'), isTrue); // vuelve a tener presupuesto
    });

    test('intentosPara devuelve 0 para una canción que nunca falló', () {
      final guard = RefreshRetryGuard();
      expect(guard.intentosPara('yt_nunca_sono'), 0);
    });

    test('el máximo de intentos es configurable', () {
      final guard = RefreshRetryGuard(maxIntentos: 1);
      expect(guard.deberiaReintentar('yt_a'), isTrue);
      expect(guard.deberiaReintentar('yt_a'), isFalse);
    });
  });
}
