import 'dart:math';

/// Lógica de la Serpiente, sin nada de Flutter adentro, para poder
/// probarla con tests igual que los otros dos juegos.
///
/// Se usa `Point<int>` de `dart:math` en vez de inventar una clase de
/// coordenadas: ya trae comparación por valor, que es justo lo que hace
/// falta para preguntar "¿la cabeza está sobre la comida?" o "¿se pisó
/// a sí misma?".

enum Direccion { arriba, abajo, izquierda, derecha }

extension _Opuesta on Direccion {
  Direccion get opuesta => switch (this) {
        Direccion.arriba => Direccion.abajo,
        Direccion.abajo => Direccion.arriba,
        Direccion.izquierda => Direccion.derecha,
        Direccion.derecha => Direccion.izquierda,
      };

  Point<int> get paso => switch (this) {
        Direccion.arriba => const Point(0, -1),
        Direccion.abajo => const Point(0, 1),
        Direccion.izquierda => const Point(-1, 0),
        Direccion.derecha => const Point(1, 0),
      };
}

class JuegoSnake {
  static const int columnas = 12;
  static const int filas = 18;
  static const int largoInicial = 3;

  final Random _azar;

  /// La cabeza es el primer elemento.
  late List<Point<int>> cuerpo;
  late Point<int> comida;
  late Direccion _direccion;

  /// El giro pedido desde los botones, que se aplica recién en el
  /// próximo paso. Sin esto, dos toques rápidos dentro del mismo paso
  /// (por ejemplo arriba y después izquierda yendo a la derecha) podrían
  /// dejar a la serpiente girando 180° y comiéndose a sí misma.
  Direccion? _giroPedido;

  int puntaje = 0;
  int nivel = 1;
  bool terminado = false;

  Direccion get direccion => _direccion;
  int get largo => cuerpo.length;

  /// [semilla] existe para los tests: con una semilla fija, la comida
  /// aparece siempre en el mismo orden.
  JuegoSnake({int? semilla}) : _azar = Random(semilla) {
    reiniciar();
  }

  void reiniciar() {
    const centroY = filas ~/ 2;
    // Arranca horizontal, mirando a la derecha, con la cabeza adelante.
    cuerpo = List.generate(
      largoInicial,
      (i) => Point(columnas ~/ 2 - i, centroY),
    );
    _direccion = Direccion.derecha;
    _giroPedido = null;
    puntaje = 0;
    nivel = 1;
    terminado = false;
    comida = _nuevaComida();
  }

  /// Cada cuánto se mueve sola. Se acelera con el nivel, con un piso
  /// para que siga siendo jugable.
  Duration get intervalo =>
      Duration(milliseconds: max(90, 260 - (nivel - 1) * 20));

  /// Pide un giro. Se ignora si es hacia donde la serpiente ya viene o
  /// hacia atrás: dar media vuelta sobre el propio cuello no es un
  /// movimiento válido, es un choque.
  void girar(Direccion nueva) {
    if (terminado) return;
    if (nueva == _direccion || nueva == _direccion.opuesta) return;
    _giroPedido = nueva;
  }

  /// Un paso del juego.
  void avanzar() {
    if (terminado) return;

    if (_giroPedido != null) {
      _direccion = _giroPedido!;
      _giroPedido = null;
    }

    final paso = _direccion.paso;
    final cabeza = cuerpo.first;
    final nuevaCabeza = Point(cabeza.x + paso.x, cabeza.y + paso.y);

    // Contra las paredes.
    if (nuevaCabeza.x < 0 ||
        nuevaCabeza.x >= columnas ||
        nuevaCabeza.y < 0 ||
        nuevaCabeza.y >= filas) {
      terminado = true;
      return;
    }

    final comio = nuevaCabeza == comida;

    // Contra sí misma. La última celda no cuenta cuando NO come, porque
    // en ese mismo paso la cola se corre y deja ese lugar libre: sin
    // esta salvedad, ir en línea recta chocaría contra la propia cola.
    final cuerpoQueEstorba =
        comio ? cuerpo : cuerpo.sublist(0, cuerpo.length - 1);
    if (cuerpoQueEstorba.contains(nuevaCabeza)) {
      terminado = true;
      return;
    }

    cuerpo.insert(0, nuevaCabeza);
    if (comio) {
      puntaje += 10;
      nivel = 1 + puntaje ~/ 50;
      comida = _nuevaComida();
    } else {
      cuerpo.removeLast();
    }
  }

  /// Busca un casillero libre para la comida. Si la serpiente llegó a
  /// ocupar el tablero entero, el juego está ganado y se da por
  /// terminado en vez de buscar para siempre un lugar que no existe.
  Point<int> _nuevaComida() {
    final libres = <Point<int>>[];
    for (var y = 0; y < filas; y++) {
      for (var x = 0; x < columnas; x++) {
        final p = Point(x, y);
        if (!cuerpo.contains(p)) libres.add(p);
      }
    }
    if (libres.isEmpty) {
      terminado = true;
      return cuerpo.first;
    }
    return libres[_azar.nextInt(libres.length)];
  }

  /// El tablero tal como hay que dibujarlo.
  List<List<int>> vista({
    required int colorCabeza,
    required int colorCuerpo,
    required int colorComida,
  }) {
    final v = List.generate(filas, (_) => List.filled(columnas, 0));
    v[comida.y][comida.x] = colorComida;
    for (var i = cuerpo.length - 1; i >= 0; i--) {
      final p = cuerpo[i];
      if (p.x < 0 || p.x >= columnas || p.y < 0 || p.y >= filas) continue;
      v[p.y][p.x] = i == 0 ? colorCabeza : colorCuerpo;
    }
    return v;
  }
}
