import 'dart:math';

/// Lógica de la carrera de autos del "brick game" clásico, sin nada de
/// Flutter adentro, para poder probarla con tests igual que el Tetris.
///
/// Son tres carriles. Tu auto va abajo y se mueve de carril; los autos
/// rivales bajan desde arriba. Chocar termina el juego; esquivarlos
/// suma puntos y acelera.
class JuegoCarrera {
  static const int carriles = 3;
  static const int filas = 16;

  /// Cada cuántos avances aparece una fila nueva de rivales. Si
  /// aparecieran en cada avance no habría hueco por donde pasar.
  static const int avancesEntreRivales = 4;

  final Random _azar;

  /// `true` donde hay un auto rival. Índice 0 es la fila de más arriba.
  late List<List<bool>> rivales;
  late int carrilJugador;

  int puntaje = 0;
  int nivel = 1;
  bool terminado = false;
  int _contadorAvances = 0;

  /// [semilla] existe para los tests: con una semilla fija, los rivales
  /// aparecen siempre en el mismo orden.
  JuegoCarrera({int? semilla}) : _azar = Random(semilla) {
    reiniciar();
  }

  void reiniciar() {
    rivales = List.generate(filas, (_) => List.filled(carriles, false));
    carrilJugador = carriles ~/ 2;
    puntaje = 0;
    nivel = 1;
    terminado = false;
    _contadorAvances = 0;
  }

  /// Cada cuánto baja todo un lugar. Se acelera con el nivel, con un
  /// piso para que siga siendo jugable.
  Duration get intervalo =>
      Duration(milliseconds: max(120, 420 - (nivel - 1) * 30));

  /// Fila donde está dibujado tu auto.
  int get filaJugador => filas - 1;

  void moverIzquierda() {
    if (terminado) return;
    if (carrilJugador > 0) carrilJugador--;
    _revisarChoque();
  }

  void moverDerecha() {
    if (terminado) return;
    if (carrilJugador < carriles - 1) carrilJugador++;
    _revisarChoque();
  }

  /// Un paso del juego: todo baja un lugar, a veces aparecen rivales
  /// nuevos arriba, y se revisa si chocaste.
  void avanzar() {
    if (terminado) return;

    // Lo que estaba en la última fila sale de la pantalla: si tu auto no
    // chocó con eso, es que lo esquivaste.
    final salieron = rivales[filas - 1].where((r) => r).length;
    if (salieron > 0) {
      puntaje += salieron * 10;
      nivel = 1 + puntaje ~/ 150;
    }

    rivales.removeAt(filas - 1);
    rivales.insert(0, List.filled(carriles, false));

    _contadorAvances++;
    if (_contadorAvances % avancesEntreRivales == 0) {
      rivales[0] = _filaDeRivales();
    }

    _revisarChoque();
  }

  /// Genera una fila con uno o dos rivales, nunca tres: siempre tiene
  /// que quedar al menos un carril libre por donde pasar.
  List<bool> _filaDeRivales() {
    final fila = List.filled(carriles, false);
    final cuantos = _azar.nextInt(carriles - 1) + 1; // 1 o 2
    final libres = List.generate(carriles, (i) => i)..shuffle(_azar);
    for (var i = 0; i < cuantos; i++) {
      fila[libres[i]] = true;
    }
    return fila;
  }

  void _revisarChoque() {
    if (rivales[filaJugador][carrilJugador]) terminado = true;
  }
}
