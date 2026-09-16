import 'dart:math';

/// Lógica del juego de disparos: un cañón abajo, bloques que bajan desde
/// arriba, y hay que destruirlos antes de que lleguen al piso. Sin nada
/// de Flutter adentro, para poder probarla con tests.

class JuegoDisparos {
  static const int columnas = 10;
  static const int filas = 18;

  /// Fila donde está el cañón (la última).
  static int get filaCanon => filas - 1;

  /// Cada cuántos pasos bajan los bloques. Las balas se mueven en cada
  /// paso: si los bloques bajaran igual de rápido, no habría tiempo de
  /// acertarles.
  static const int pasosEntreBajadas = 6;

  /// Cada cuántas bajadas entra una fila nueva de bloques.
  static const int bajadasEntreFilas = 3;

  final Random _azar;

  /// `true` donde hay un bloque. La fila 0 es la de más arriba.
  late List<List<bool>> bloques;

  /// Posición de cada bala en vuelo.
  late List<Point<int>> balas;

  late int columnaCanon;

  int puntaje = 0;
  int nivel = 1;
  bool terminado = false;
  int _pasos = 0;
  int _bajadas = 0;

  /// [semilla] existe para los tests: con una semilla fija, los bloques
  /// aparecen siempre en el mismo orden.
  JuegoDisparos({int? semilla}) : _azar = Random(semilla) {
    reiniciar();
  }

  void reiniciar() {
    bloques = List.generate(filas, (_) => List.filled(columnas, false));
    balas = [];
    columnaCanon = columnas ~/ 2;
    puntaje = 0;
    nivel = 1;
    terminado = false;
    _pasos = 0;
    _bajadas = 0;
  }

  /// Cada cuánto corre el juego. Se acelera con el nivel, con un piso
  /// para que siga siendo jugable.
  Duration get intervalo =>
      Duration(milliseconds: max(55, 130 - (nivel - 1) * 12));

  void moverIzquierda() {
    if (terminado) return;
    if (columnaCanon > 0) columnaCanon--;
  }

  void moverDerecha() {
    if (terminado) return;
    if (columnaCanon < columnas - 1) columnaCanon++;
  }

  /// Dispara desde el cañón. Hay un tope de balas en vuelo para que
  /// mantener apretado el botón no vuelva el juego trivial.
  void disparar() {
    if (terminado) return;
    if (balas.length >= 3) return;
    balas.add(Point(columnaCanon, filaCanon - 1));
    // Se resuelve el impacto ya mismo: si no, una bala disparada contra
    // un bloque que está justo encima del cañón nacería sobre él y
    // recién se revisaría después de subir un casillero, o sea que lo
    // atravesaría sin tocarlo.
    _resolverImpactos();
  }

  /// Un paso del juego: las balas suben, cada tantos pasos los bloques
  /// bajan, y cada tantas bajadas entra una fila nueva.
  void avanzar() {
    if (terminado) return;
    _pasos++;

    _moverBalas();

    if (_pasos % pasosEntreBajadas == 0) {
      _bajarBloques();
      if (terminado) return;
      _bajadas++;
      if (_bajadas % bajadasEntreFilas == 0) _nuevaFila();
      // Los bloques se movieron: puede haber quedado alguno justo donde
      // hay una bala.
      _resolverImpactos();
    }
  }

  void _moverBalas() {
    final quedan = <Point<int>>[];
    for (final b in balas) {
      final arriba = Point(b.x, b.y - 1);
      if (arriba.y < 0) continue; // se fue por arriba
      quedan.add(arriba);
    }
    balas = quedan;
    _resolverImpactos();
  }

  /// Saca las balas que están sobre un bloque, junto con el bloque.
  void _resolverImpactos() {
    final quedan = <Point<int>>[];
    for (final b in balas) {
      if (b.y >= 0 && b.y < filas && bloques[b.y][b.x]) {
        bloques[b.y][b.x] = false;
        puntaje += 10;
        nivel = 1 + puntaje ~/ 100;
      } else {
        quedan.add(b);
      }
    }
    balas = quedan;
  }

  void _bajarBloques() {
    // Si la fila de más abajo antes de bajar ya tiene algo, al bajar
    // llegaría al cañón: ahí se termina.
    if (bloques[filas - 2].any((b) => b)) {
      terminado = true;
      return;
    }
    bloques.removeAt(filas - 1);
    bloques.insert(0, List.filled(columnas, false));
  }

  /// Genera una fila con bloques salteados. Nunca la llena entera: hay
  /// que poder pasar las balas y ver qué viene.
  void _nuevaFila() {
    final fila = List.filled(columnas, false);
    final cuantos = 2 + _azar.nextInt(3); // entre 2 y 4
    final posiciones = List.generate(columnas, (i) => i)..shuffle(_azar);
    for (var i = 0; i < cuantos; i++) {
      fila[posiciones[i]] = true;
    }
    bloques[0] = fila;
  }

  /// El tablero tal como hay que dibujarlo.
  List<List<int>> vista({
    required int colorCanon,
    required int colorBala,
    required int colorBloque,
  }) {
    final v = List.generate(filas, (_) => List.filled(columnas, 0));
    for (var y = 0; y < filas; y++) {
      for (var x = 0; x < columnas; x++) {
        if (bloques[y][x]) v[y][x] = colorBloque;
      }
    }
    for (final b in balas) {
      if (b.y >= 0 && b.y < filas) v[b.y][b.x] = colorBala;
    }
    v[filaCanon][columnaCanon] = colorCanon;
    return v;
  }
}
