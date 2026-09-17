import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/widgets/song_cover.dart';

/// La carátula de una canción. Es la pieza que MÁS veces se dibuja en
/// toda la app: una por cada fila de la lista, una en cada tarjeta de
/// los carruseles, una en el mini reproductor y una grande en el
/// reproductor.
///
/// Por eso acá se arreglaron varias cosas de rendimiento a ciegas, y
/// estos tests las fijan.
///
/// Se prueba con la tapa ya conocida (`coverUrlDirecto`), que es como
/// llegan las de Descubrir: en ese caso la carátula se resuelve sin
/// esperar nada, sin tocar el disco ni la red.

Widget _conCaratula({
  String coverUrlDirecto = '',
  double size = 45,
  bool showShadow = false,
  double densidad = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(devicePixelRatio: densidad),
      child: Scaffold(
        body: Center(
          child: SongCover(
            title: 'Te Quiero',
            artist: 'Amén',
            url: '',
            coverUrlDirecto: coverUrlDirecto,
            size: size,
            showShadow: showShadow,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('SongCover', () {
    testWidgets('con la tapa ya conocida NO muestra la ruedita',
        (tester) async {
      // Antes toda carátula pasaba por una espera, incluso una ya
      // resuelta. Y hasta la espera más corta cuesta un cuadro entero:
      // primero se dibuja la ruedita y recién en el siguiente la
      // imagen. Al desplazar una lista larga eso es un parpadeo de
      // ruedas en cada fila que entra en pantalla.
      await tester.pumpWidget(
          _conCaratula(coverUrlDirecto: 'https://ejemplo.test/tapa.jpg'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'parpadeó la ruedita con la tapa ya conocida');
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('sin ninguna tapa muestra el dibujito, no una ruedita eterna',
        (tester) async {
      await tester.pumpWidget(_conCaratula());
      await tester.pump();
      // Se deja que la búsqueda termine (falla sin red, que es lo
      // esperado en un test) y se comprueba que queda el placeholder.
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
    });

    testWidgets('pide la imagen al TAMAÑO REAL de pantalla', (tester) async {
      // Las carátulas vienen a 600x600 o más. Sin pedirlas al tamaño en
      // que se van a ver, Flutter las descomprime enteras en memoria
      // aunque se dibujen en un cuadradito de 45: más de un mega por
      // fila, y una biblioteca de cientos recorrida de punta a punta
      // trababa el desplazamiento en celulares de gama media.
      await tester.pumpWidget(_conCaratula(
        coverUrlDirecto: 'https://ejemplo.test/tapa.jpg',
        size: 45,
        densidad: 3.0,
      ));
      await tester.pump();

      final imagen = tester.widget<Image>(find.byType(Image));
      final proveedor = imagen.image as ResizeImage;
      expect(proveedor.width, 135, reason: '45 de alto por 3 de densidad');
    });

    testWidgets('NO fija el alto: eso deformaba las tapas no cuadradas',
        (tester) async {
      // Dando ancho Y alto, Flutter descomprime a esas medidas exactas
      // y deja de respetar la proporción: una tapa rectangular --las
      // hay, sobre todo las que vienen dentro del MP3-- se aplastaba
      // para entrar en el cuadrado, y después el recorte ya no podía
      // arreglarlo porque recibía la imagen deformada.
      await tester.pumpWidget(_conCaratula(
        coverUrlDirecto: 'https://ejemplo.test/tapa.jpg',
        densidad: 2.0,
      ));
      await tester.pump();

      final proveedor =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect(proveedor.height, isNull,
          reason: 'con alto fijo las tapas no cuadradas salen aplastadas');
    });

    testWidgets('la imagen se recorta, no se estira', (tester) async {
      await tester.pumpWidget(
          _conCaratula(coverUrlDirecto: 'https://ejemplo.test/tapa.jpg'));
      await tester.pump();

      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    });

    testWidgets('mide lo que se le pidió', (tester) async {
      await tester.pumpWidget(_conCaratula(
        coverUrlDirecto: 'https://ejemplo.test/tapa.jpg',
        size: 120,
      ));
      await tester.pump();

      final caja = tester.getSize(find.byType(SongCover));
      expect(caja.width, 120);
      expect(caja.height, 120);
    });

    testWidgets('la sombra es opcional y no cambia el tamaño', (tester) async {
      await tester.pumpWidget(_conCaratula(
        coverUrlDirecto: 'https://ejemplo.test/tapa.jpg',
        size: 100,
        showShadow: true,
      ));
      await tester.pump();

      expect(tester.getSize(find.byType(SongCover)).width, 100);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cambiar de canción vuelve a resolver la tapa',
        (tester) async {
      // Las listas reciclan las filas: la misma instancia pasa a
      // representar otra canción. Sin darse cuenta, la fila nueva
      // mostraría la tapa de la anterior.
      Widget con(String tapa, String titulo) => MaterialApp(
            home: Scaffold(
              body: SongCover(
                title: titulo,
                artist: 'Alguien',
                url: '',
                coverUrlDirecto: tapa,
                size: 45,
              ),
            ),
          );

      await tester.pumpWidget(con('https://ejemplo.test/una.jpg', 'Una'));
      await tester.pump();
      final primera =
          (tester.widget<Image>(find.byType(Image)).image as ResizeImage)
              .imageProvider as NetworkImage;

      await tester.pumpWidget(con('https://ejemplo.test/otra.jpg', 'Otra'));
      await tester.pump();
      final segunda =
          (tester.widget<Image>(find.byType(Image)).image as ResizeImage)
              .imageProvider as NetworkImage;

      expect(segunda.url, isNot(primera.url),
          reason: 'la fila reciclada se quedó con la tapa de la anterior');
    });
  });
}
