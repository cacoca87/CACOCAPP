import 'dart:math';

/// Lógica del Tetris, sin nada de Flutter adentro.
///
/// Vive aparte de la pantalla para poder probarla con tests: las reglas
/// del juego (choques, rotación, líneas completas, puntaje) son
/// justamente lo que conviene tener cubierto, y no hace falta dibujar
/// nada para verificarlas. Mismo criterio que `lyrics_parsing.dart` o
/// `nombre_archivo_parser.dart`.
///
/// El tablero es una matriz de enteros: 0 es celda vacía y cualquier
/// número mayor identifica el color de la pieza que quedó ahí.

/// Las siete piezas clásicas, cada una como una matriz cuadrada. Se usan
/// matrices cuadradas (y no la forma justa) porque así rotar es girar la
/// matriz 90°, sin casos especiales por pieza.
const List<List<List<int>>> formasIniciales = [
  // I
  [
    [0, 0, 0, 0],
    [1, 1, 1, 1],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
  ],
  // O
  [
    [2, 2],
    [2, 2],
  ],
  // T
  [
    [0, 3, 0],
    [3, 3, 3],
    [0, 0, 0],
  ],
  // S
  [
    [0, 4, 4],
    [4, 4, 0],
    [0, 0, 0],
  ],
  // Z
  [
    [5, 5, 0],
    [0, 5, 5],
    [0, 0, 0],
  ],
  // J
  [
    [6, 0, 0],
    [6, 6, 6],
    [0, 0, 0],
  ],
  // L
  [
    [0, 0, 7],
    [7, 7, 7],
    [0, 0, 0],
  ],
];

/// Gira una matriz cuadrada 90° en sentido horario.
List<List<int>> rotarMatriz(List<List<int>> m) {
  final n = m.length;
  return List.generate(
    n,
    (fila) => List.generate(n, (col) => m[n - 1 - col][fila]),
  );
}

/// Puntos por cantidad de líneas hechas de una sola vez. Hacer varias
/// juntas rinde mucho más que hacerlas de a una, que es lo que vuelve
/// interesante arriesgarse a esperar la pieza larga.
int puntajePorLineas(int lineas, int nivel) {
  const base = {1: 100, 2: 300, 3: 500, 4: 800};
  return (base[lineas] ?? 0) * nivel;
}

class JuegoTetris {
  static const int columnas = 10;
  static const int filas = 20;

  final Random _azar;

  late List<List<int>> tablero;
  List<List<int>>? forma;
  int filaPieza = 0;
  int colPieza = 0;

  int puntaje = 0;
  int lineasHechas = 0;
  int nivel = 1;
  bool terminado = false;

  /// [semilla] existe para los tests: con una semilla fija, la secuencia
  /// de piezas es siempre la misma y se puede afirmar qué pasa.
  JuegoTetris({int? semilla}) : _azar = Random(semilla) {
    reiniciar();
  }

  void reiniciar() {
    tablero = List.generate(filas, (_) => List.filled(columnas, 0));
    puntaje = 0;
    lineasHechas = 0;
    nivel = 1;
    terminado = false;
    _nuevaPieza();
  }

  /// Cada cuánto baja sola la pieza. Se acelera con el nivel, con un
  /// piso para que siga siendo jugable.
  Duration get intervalo =>
      Duration(milliseconds: max(140, 700 - (nivel - 1) * 60));

  void _nuevaPieza() {
    forma = formasIniciales[_azar.nextInt(formasIniciales.length)]
        .map((f) => List<int>.from(f))
        .toList();
    filaPieza = 0;
    colPieza = (columnas - forma!.length) ~/ 2;
    // Si la pieza nueva ya no entra, se terminó el juego.
    if (_colisiona(forma!, filaPieza, colPieza)) {
      terminado = true;
      forma = null;
    }
  }

  bool _colisiona(List<List<int>> f, int fila, int col) {
    for (var i = 0; i < f.length; i++) {
      for (var j = 0; j < f[i].length; j++) {
        if (f[i][j] == 0) continue;
        final y = fila + i;
        final x = col + j;
        if (x < 0 || x >= columnas || y >= filas) return true;
        // y < 0 se permite: la pieza puede asomar por arriba del tablero
        // mientras entra.
        if (y >= 0 && tablero[y][x] != 0) return true;
      }
    }
    return false;
  }

  bool moverIzquierda() => _mover(-1);
  bool moverDerecha() => _mover(1);

  bool _mover(int dx) {
    if (terminado || forma == null) return false;
    if (_colisiona(forma!, filaPieza, colPieza + dx)) return false;
    colPieza += dx;
    return true;
  }

  /// Rota la pieza. Si al rotar queda pisando una pared o una pieza, se
  /// prueba correrla un lugar a cada lado antes de rendirse -- sin eso,
  /// rotar pegado al borde no funciona nunca y se siente roto.
  bool rotar() {
    if (terminado || forma == null) return false;
    final rotada = rotarMatriz(forma!);
    for (final desplazamiento in [0, -1, 1, -2, 2]) {
      if (!_colisiona(rotada, filaPieza, colPieza + desplazamiento)) {
        forma = rotada;
        colPieza += desplazamiento;
        return true;
      }
    }
    return false;
  }

  /// Baja la pieza un lugar. Devuelve `false` si ya no pudo bajar, que
  /// es cuando queda fija y entra una nueva.
  bool bajar() {
    if (terminado || forma == null) return false;
    if (!_colisiona(forma!, filaPieza + 1, colPieza)) {
      filaPieza++;
      return true;
    }
    _fijarPieza();
    return false;
  }

  /// Tira la pieza hasta abajo de una vez.
  void caidaRapida() {
    if (terminado || forma == null) return;
    while (!_colisiona(forma!, filaPieza + 1, colPieza)) {
      filaPieza++;
    }
    _fijarPieza();
  }

  void _fijarPieza() {
    final f = forma!;
    for (var i = 0; i < f.length; i++) {
      for (var j = 0; j < f[i].length; j++) {
        if (f[i][j] == 0) continue;
        final y = filaPieza + i;
        final x = colPieza + j;
        if (y >= 0 && y < filas && x >= 0 && x < columnas) {
          tablero[y][x] = f[i][j];
        }
      }
    }
    final completadas = _eliminarLineas();
    if (completadas > 0) {
      lineasHechas += completadas;
      puntaje += puntajePorLineas(completadas, nivel);
      nivel = 1 + lineasHechas ~/ 10;
    }
    _nuevaPieza();
  }

  int _eliminarLineas() {
    var eliminadas = 0;
    for (var y = filas - 1; y >= 0; y--) {
      if (tablero[y].every((c) => c != 0)) {
        tablero.removeAt(y);
        tablero.insert(0, List.filled(columnas, 0));
        eliminadas++;
        y++; // volver a mirar esta misma fila, que ahora tiene otra
      }
    }
    return eliminadas;
  }

  /// El tablero tal como hay que dibujarlo: lo ya fijado más la pieza
  /// que está cayendo. Se devuelve una copia para que la pantalla no
  /// pueda modificar el estado del juego sin querer.
  List<List<int>> get vista {
    final v = tablero.map((f) => List<int>.from(f)).toList();
    final f = forma;
    if (f == null) return v;
    for (var i = 0; i < f.length; i++) {
      for (var j = 0; j < f[i].length; j++) {
        if (f[i][j] == 0) continue;
        final y = filaPieza + i;
        final x = colPieza + j;
        if (y >= 0 && y < filas && x >= 0 && x < columnas) {
          v[y][x] = f[i][j];
        }
      }
    }
    return v;
  }
}
