import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/screens/juegos_screen.dart';
import 'package:CACOCAPP/widgets/tarjeta_tocable.dart';
import 'package:CACOCAPP/widgets/vista_spotify_grid.dart';

/// El destello que se expande bajo el dedo al tocar una tarjeta.
///
/// Es la única señal de que la app registró el toque, y **no la dibuja
/// el `InkWell`**: la dibuja la capa `Material` más cercana por debajo.
/// Si entre los dos hay algo con fondo opaco --la tarjeta con su propio
/// color, por ejemplo-- el destello queda tapado y la tarjeta se siente
/// muerta al tocarla, aunque funcione.
///
/// No tira ningún error y no se ve leyendo el código. Estaba así en
/// seis lugares de los más tocados de la app.

/// El color de fondo que pinta un widget, o `null` si no pinta ninguno.
Color? _fondoDe(Widget w) {
  if (w is ColoredBox) return w.color;
  if (w is Material) return w.color;
  if (w is DecoratedBox) {
    final d = w.decoration;
    return d is BoxDecoration ? d.color : null;
  }
  if (w is Container) {
    if (w.color != null) return w.color;
    final d = w.decoration;
    return d is BoxDecoration ? d.color : null;
  }
  return null;
}

/// Comprueba que el destello de este `InkWell` se va a ver.
///
/// Se mira hacia ABAJO, no hacia arriba, que es la parte que cuesta
/// entender de este fallo: el destello lo pinta una capa que está
/// **debajo** del `InkWell`, así que lo que lo tapa es algo que está
/// **encima**, o sea uno de sus propios hijos.
///
/// Lo que se busca es un hijo con fondo opaco que ocupe **toda** la
/// zona tocable. Un fondo chico no molesta: el cuadradito de color del
/// ícono, por ejemplo, deja ver el destello alrededor.
///
/// Devuelve qué lo tapa, o una lista vacía si está todo bien.
List<String> _loQueTapaElDestello(WidgetTester tester, Finder inkWell) {
  final tapadores = <String>[];
  final zonaTocable = tester.getSize(inkWell);

  bool cubreTodo(Element e) {
    final ro = e.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return false;
    return ro.size.width >= zonaTocable.width - 0.5 &&
        ro.size.height >= zonaTocable.height - 0.5;
  }

  void mirarHijo(Element e) {
    if (_pintaFondoOpaco(e.widget) && cubreTodo(e)) {
      tapadores.add(e.widget.runtimeType.toString());
      return; // ya está tapado: no hace falta seguir bajando por acá
    }
    e.visitChildren(mirarHijo);
  }

  tester.element(inkWell).visitChildren(mirarHijo);

  // Y sin ninguna capa `Material` arriba no hay quién dibuje el
  // destello: ni siquiera llegaría a estar tapado.
  var huboMaterial = false;
  tester.element(inkWell).visitAncestorElements((a) {
    if (a.widget is Material) {
      huboMaterial = true;
      return false;
    }
    return true;
  });
  if (!huboMaterial) tapadores.add('no hay ninguna capa Material arriba');

  return tapadores;
}

bool _pintaFondoOpaco(Widget w) {
  if (w is Material) return w.color != null && w.color!.a >= 1.0;
  final fondo = _fondoDe(w);
  if (fondo != null && fondo.a >= 1.0) return true;
  // Un degradado también tapa, y no vive en `color`.
  final d = w is Container
      ? w.decoration
      : w is DecoratedBox
          ? w.decoration
          : null;
  return d is BoxDecoration && d.gradient != null;
}

void esperaDestelloVisible(WidgetTester tester, Finder inkWells) {
  expect(inkWells, findsWidgets, reason: 'no se encontró ningún InkWell');
  for (var i = 0; i < tester.widgetList(inkWells).length; i++) {
    final tapadores = _loQueTapaElDestello(tester, inkWells.at(i));
    expect(tapadores, isEmpty,
        reason: 'el destello del toque queda tapado por: '
            '${tapadores.join(", ")}');
  }
}

void main() {
  group('TarjetaTocable', () {
    testWidgets('el destello se ve: nada opaco entre el toque y su capa',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TarjetaTocable(
            onTap: () {},
            child: const Text('una tarjeta'),
          ),
        ),
      ));

      esperaDestelloVisible(tester, find.byType(InkWell));
    });

    testWidgets('con borde también', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TarjetaTocable(
            onTap: () {},
            borde: Border.all(color: Colors.amber),
            child: const Text('con borde'),
          ),
        ),
      ));

      esperaDestelloVisible(tester, find.byType(InkWell));
    });

    testWidgets('con sombra también', (tester) async {
      // La sombra va en una caja de afuera SIN color: si llevara color
      // volvería a tapar el destello, que es el problema entero.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TarjetaTocable(
            onTap: () {},
            sombra: const [BoxShadow(color: Colors.black, blurRadius: 8)],
            child: const Text('con sombra'),
          ),
        ),
      ));

      esperaDestelloVisible(tester, find.byType(InkWell));
    });

    testWidgets('el toque llega', (tester) async {
      var toques = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TarjetaTocable(
            onTap: () => toques++,
            child: const Text('tocame'),
          ),
        ),
      ));

      await tester.tap(find.text('tocame'));
      await tester.pump();

      expect(toques, 1);
    });

    testWidgets('el contenido queda dentro del relleno pedido',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: TarjetaTocable(
              onTap: () {},
              padding: const EdgeInsets.all(20),
              child: const SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      ));

      final tarjeta = tester.getSize(find.byType(TarjetaTocable));
      expect(tarjeta.width, 50 + 40);
      expect(tarjeta.height, 50 + 40);
    });

    testWidgets('el detector de tapados NO es un test que siempre pasa',
        (tester) async {
      // Si esta comprobación no detectara nada, los tests de arriba
      // pasarían igual estando todo mal. Acá se arma a propósito el
      // error que este widget existe para evitar.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: InkWell(
            onTap: () {},
            child: Container(
              color: const Color(0xFF202020),
              child: const Text('mal armada'),
            ),
          ),
        ),
      ));

      expect(_loQueTapaElDestello(tester, find.byType(InkWell)), isNotEmpty,
          reason: 'la comprobación tiene que agarrar este caso');
    });
  });

  group('las pantallas que usaban el orden equivocado', () {
    testWidgets('las tarjetas de los juegos muestran el destello',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: JuegosScreen()));
      await tester.pump();

      esperaDestelloVisible(tester, find.byType(InkWell));
    });

    testWidgets('las tarjetas de Artistas y Álbumes muestran el destello',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: VistaSpotifyGrid(
            titulo: 'Artistas',
            tituloSingular: 'Artista',
            elementos: const ['Soda Stereo', 'Amén', 'Los Redondos'],
            icono: Icons.person_rounded,
            esPantallaPequena: true,
            onSeleccionarElemento: (_) {},
          ),
        ),
      ));
      await tester.pump();

      esperaDestelloVisible(tester, find.byType(InkWell));
    });
  });
}
