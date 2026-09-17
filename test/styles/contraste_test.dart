import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/styles/app_theme.dart';

/// ¿Se lee el texto de la app?
///
/// No es una opinión: hay una cuenta estándar para medirlo. Se compara
/// cuánta luz refleja el texto contra cuánta refleja el fondo, y el
/// resultado va de 1 (invisible) a 21 (negro sobre blanco). La regla
/// más usada --WCAG AA-- pide **4,5 como mínimo** para un texto normal
/// y **3 para un texto grande**.
///
/// Esto existe porque un color se elige mirando la pantalla de la
/// computadora, con luz de interior y a cincuenta centímetros. El
/// celular se usa en la calle, al sol y con el brillo bajo para ahorrar
/// batería. Ahí un gris que "se veía bien" deja de leerse.
///
/// Y ya pasó: el gris de los renglones de la letra que todavía no
/// suenan daba 3,3. Son justo los que se leen para ir siguiendo la
/// canción.

/// Cuánta luz refleja un color, del 0 (negro) al 1 (blanco).
double _luminancia(Color c) {
  double canal(double v) {
    final s = v;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

/// La cuenta estándar de contraste entre dos colores. Da de 1 a 21.
double contraste(Color a, Color b) {
  final la = _luminancia(a);
  final lb = _luminancia(b);
  final claro = math.max(la, lb);
  final oscuro = math.min(la, lb);
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  group('el texto de la app se lee', () {
    // El mínimo de la regla estándar para un texto normal.
    const minimoTextoNormal = 4.5;

    // Cada color de texto con el fondo sobre el que se dibuja de
    // verdad. Están los tres fondos de la app.
    const casos = {
      'texto principal sobre el fondo': [AppTheme.paper, AppTheme.ink],
      'texto secundario sobre el fondo': [AppTheme.mutedInk, AppTheme.ink],
      'texto terciario sobre el fondo': [AppTheme.faintInk, AppTheme.ink],
      'texto principal sobre una tarjeta': [AppTheme.paper, AppTheme.surface],
      'texto secundario sobre una tarjeta': [
        AppTheme.mutedInk,
        AppTheme.surface
      ],
      'texto terciario sobre una tarjeta': [
        AppTheme.faintInk,
        AppTheme.surface
      ],
      'texto principal sobre algo elevado': [
        AppTheme.paper,
        AppTheme.surfaceRaised
      ],
      'texto secundario sobre algo elevado': [
        AppTheme.mutedInk,
        AppTheme.surfaceRaised
      ],
      'el ámbar de los acentos sobre el fondo': [AppTheme.amber, AppTheme.ink],
      'el rojo de los errores sobre el fondo': [AppTheme.danger, AppTheme.ink],
    };

    casos.forEach((nombre, colores) {
      test(nombre, () {
        final medido = contraste(colores[0], colores[1]);
        expect(medido, greaterThanOrEqualTo(minimoTextoNormal),
            reason: '$nombre da ${medido.toStringAsFixed(2)} y el mínimo '
                'para leerse cómodo es $minimoTextoNormal');
      });
    });

    test('el gris de la letra que no suena se arregló de verdad', () {
      // El valor viejo era 0xFF6E6459 y daba 3,3. Se deja el número
      // acá para que se vea de dónde se venía.
      const elViejo = Color(0xFF6E6459);
      expect(contraste(elViejo, AppTheme.ink), lessThan(minimoTextoNormal),
          reason: 'el valor viejo tenía que estar por debajo del mínimo');
      expect(contraste(AppTheme.faintInk, AppTheme.ink),
          greaterThan(contraste(elViejo, AppTheme.ink)),
          reason: 'el valor nuevo tiene que leerse mejor que el viejo');
    });

    test('el texto oscuro sobre el ámbar también se lee', () {
      // El ámbar se usa de fondo en los carteles de aviso, y ahí el
      // texto va oscuro: crema sobre ámbar da 1,9 y al sol no se lee.
      //
      // Se compara el color directamente y no a través de
      // `AppTheme.textoSobreAmbar`, porque ese estilo trae una
      // tipografía que hay que cargar de un archivo y eso no se puede
      // hacer en un test suelto. El color es el mismo.
      expect(contraste(AppTheme.ink, AppTheme.amber),
          greaterThanOrEqualTo(minimoTextoNormal));

      // Y se deja constancia de por qué NO se usa el crema ahí.
      expect(contraste(AppTheme.paper, AppTheme.amber),
          lessThan(minimoTextoNormal));
    });
  });
}
