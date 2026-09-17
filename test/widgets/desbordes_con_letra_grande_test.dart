import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/models/playlist.dart';
import 'package:CACOCAPP/models/song.dart';
import 'package:CACOCAPP/widgets/barra_lateral.dart';
import 'package:CACOCAPP/widgets/carrusel_playlists.dart';
import 'package:CACOCAPP/screens/juegos_screen.dart';
import 'package:CACOCAPP/widgets/estado_vacio.dart';
import 'package:CACOCAPP/widgets/tarjeta_tocable.dart';
import 'package:CACOCAPP/widgets/vista_spotify_grid.dart';

/// EL BUG QUE MÁS SE REPITIÓ EN ESTE PROYECTO
///
/// Varias partes de la app reservaban un alto o un ancho FIJO, medido
/// con la letra del sistema en su tamaño normal. Con la letra agrandada
/// --que es lo que traen de fábrica varios Samsung, y algo que mucha
/// gente sube a mano-- el texto dejaba de entrar y Flutter dibujaba las
/// rayas amarillas y negras de "desbordado".
///
/// Aparecieron así los carruseles de Inicio (la PRIMERA pantalla que se
/// ve al abrir la app), el menú lateral y el ecualizador. Cada uno se
/// encontró leyendo, de a uno.
///
/// Estos tests los agarran solos: Flutter avisa del desbordado como una
/// excepción durante el dibujado, y `tester.takeException()` la
/// atrapa. Así el arreglo queda trabado y no puede volver sin que algo
/// se ponga en rojo.

/// Achica la pantalla de la prueba al tamaño de un celular angosto, que
/// es donde primero falta lugar.
///
/// Hace falta tocar `tester.view`: poner el tamaño en el `MediaQuery`
/// **no achica nada**, solo cambia el número que los widgets leen. La
/// superficie donde se dibuja sigue siendo la de fábrica --800 de
/// ancho, más que cualquier teléfono--, así que los tests decían probar
/// un celular angosto y en realidad probaban una tablet.
void _pantallaDeCelular(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _conLetraDeTamano(double escala, Widget hijo) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(escala)),
      child: Scaffold(body: hijo),
    ),
  );
}

Playlist _playlist(String nombre, int canciones) => Playlist(
      id: nombre,
      name: nombre,
      songs: List.generate(
        canciones,
        (i) => Song(
          id: '$nombre$i',
          title: 'Tema $i',
          artist: 'Artista',
          album: 'Album',
          url: '',
          coverUrl: '',
        ),
      ),
    );

void main() {
  // 1.0 es la letra normal; 2.0 es el máximo que deja poner Android en
  // accesibilidad. Se prueban los dos extremos y el punto intermedio
  // que traen varios teléfonos de fábrica.
  const escalas = [1.0, 1.3, 1.6, 2.0];

  group('con la letra del sistema agrandada, nada se desborda', () {
    for (final escala in escalas) {
      testWidgets('el carrusel de playlists (letra x$escala)', (tester) async {
        _pantallaDeCelular(tester);
        await tester.pumpWidget(_conLetraDeTamano(
          escala,
          CarruselPlaylists(
            titulo: 'Tus playlists',
            playlists: [
              _playlist('Rock', 12),
              _playlist('Para correr un rato largo', 1),
            ],
            esPantallaPequena: true,
            onVerTodo: () {},
            onSeleccionarPlaylist: (_) {},
          ),
        ));
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'con la letra x$escala se desbordó el carrusel');
      });

      testWidgets('el menú lateral (letra x$escala)', (tester) async {
        _pantallaDeCelular(tester);
        await tester.pumpWidget(_conLetraDeTamano(
          escala,
          BarraLateral(
            seccionActiva: 'Tu Biblioteca',
            bibliotecaSeleccionada: 'Toda tu música',
            bibliotecas: const [
              'Toda tu música',
              'Favoritos',
              'Una playlist con un nombre larguísimo a propósito',
            ],
            controladorNuevaBib: TextEditingController(),
            onCambiarSeccion: (_) {},
            onSeleccionarBiblioteca: (_) {},
            onCrearBiblioteca: () {},
          ),
        ));
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'con la letra x$escala se desbordó el menú lateral');
      });

      testWidgets('el mensaje de "no hay nada" (letra x$escala)',
          (tester) async {
        _pantallaDeCelular(tester);
        await tester.pumpWidget(_conLetraDeTamano(
          escala,
          const EstadoVacio(
            icono: Icons.music_off_rounded,
            mensaje: 'Todavía no descargaste ninguna canción. Tocá el ícono '
                'de descarga en cualquier canción de tu biblioteca para '
                'guardarla y escucharla sin conexión.',
          ),
        ));
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'con la letra x$escala se desbordó el mensaje');
      });
    }
  });

  group('las pantallas que se tocaron en la vuelta 91', () {
    for (final escala in escalas) {
      testWidgets('el menú de Juegos (letra x$escala)', (tester) async {
        // Las cuatro tarjetas llevan una descripción de dos renglones
        // al lado de un ícono y una flecha, en un ancho fijo.
        _pantallaDeCelular(tester);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(escala)),
            child: const JuegosScreen(),
          ),
        ));
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'con la letra x$escala se desbordó el menú de Juegos');
      });

      testWidgets('la grilla de Artistas con nombres largos (letra x$escala)',
          (tester) async {
        _pantallaDeCelular(tester);
        await tester.pumpWidget(_conLetraDeTamano(
          escala,
          VistaSpotifyGrid(
            titulo: 'Artistas',
            tituloSingular: 'Artista',
            elementos: const [
              'Los Fabulosos Cadillacs',
              'Amén',
              'Sumo',
              'El Cuarteto de Nos y una banda con un nombre interminable',
            ],
            icono: Icons.person_rounded,
            esPantallaPequena: true,
            onSeleccionarElemento: (_) {},
          ),
        ));
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'con la letra x$escala se desbordó la grilla');
      });
    }

    testWidgets('una tarjeta tocable con un texto larguísimo', (tester) async {
      _pantallaDeCelular(tester);
      await tester.pumpWidget(_conLetraDeTamano(
        2.0,
        TarjetaTocable(
          onTap: () {},
          child: const Row(
            children: [
              Icon(Icons.music_note_rounded),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Un texto absurdamente largo que jamás entraría en una '
                  'pantalla de trescientos veinte píxeles con la letra '
                  'al doble',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('los textos largos se recortan en vez de romper la fila', () {
    testWidgets('un nombre de playlist larguísimo no rompe el menú lateral',
        (tester) async {
      _pantallaDeCelular(tester);
      await tester.pumpWidget(_conLetraDeTamano(
        1.0,
        BarraLateral(
          seccionActiva: 'Tu Biblioteca',
          bibliotecaSeleccionada: 'Toda tu música',
          bibliotecas: const [
            'Toda tu música',
            'Esta playlist tiene un nombre absurdamente largo que jamás entraría en una barra de doscientos cuarenta píxeles',
          ],
          controladorNuevaBib: TextEditingController(),
          onCambiarSeccion: (_) {},
          onSeleccionarBiblioteca: (_) {},
          onCrearBiblioteca: () {},
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
