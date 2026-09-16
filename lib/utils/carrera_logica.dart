import 'dart:math';

/// Lógica de la carrera de autos del "brick game" clásico, sin nada de
/// Flutter adentro, para poder probarla con tests igual que Bloques.
///
/// A diferencia de la primera versión, donde cada auto era un solo
/// cuadrito, acá los autos se dibujan con la forma del juego original:
/// una figura de 4×3 casilleros. Por eso la pista tiene carriles de
/// **tres casilleros de ancho cada uno**, y aprovecha mucho mejor la
/// pantalla que la versión de un casillero por carril.

/// La silueta del auto, igual que en el aparatito: techo, capó ancho,
/// cuerpo y ruedas traseras.
const List<List<int>> formaAuto = [
  [0, 1, 0],
  [1, 1, 1],
  [0, 1, 0],
  [1, 0, 1],
];

/// Un auto rival en la pista. [fila] es la fila de su casillero de más
/// arriba, y puede ser negativa mientras el auto está entrando.
class AutoRival {
  final int carril;
  int fila;
  AutoRival({required this.carril, required this.fila});
}

class JuegoCarrera {
  /// Cuatro carriles y no tres.
  ///
  /// Con tres, la pista quedaba tan angosta que cuando un rival venía
  /// cerca no había a dónde ir: desde el carril de un costado solo se
  /// alcanza el del medio, y si el rival estaba ahí, no se podía cruzar
  /// al otro lado. Con cuatro hay lugar de verdad para moverse, y de
  /// paso la pista aprovecha mejor el ancho de la pantalla.
  static const int carriles = 4;
  static const int anchoCarril = 3;
  static const int columnas = carriles * anchoCarril;
  static const int filas = 20;
  static const int altoAuto = 4;

  /// Cada cuántos avances entra un auto rival nuevo.
  ///
  /// Tiene que ser MAYOR que los avances que un rival pasa dentro de la
  /// zona donde puede chocarte (7): si fueran iguales, apenas se va uno
  /// ya está el siguiente encima y nunca hay un respiro. Con 9 queda un
  /// margen real para acomodarse antes del próximo.
  static const int avancesEntreRivales = 9;

  final Random _azar;

  late List<AutoRival> rivales;
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
    rivales = [];
    carrilJugador = carriles ~/ 2;
    puntaje = 0;
    nivel = 1;
    terminado = false;
    _contadorAvances = 0;
  }

  /// Cada cuánto baja todo un casillero. Se acelera con el nivel, con un
  /// piso para que siga siendo jugable.
  Duration get intervalo =>
      Duration(milliseconds: max(90, 260 - (nivel - 1) * 22));

  /// Fila del casillero de más arriba de tu auto.
  int get filaJugador => filas - altoAuto;

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

  /// Un paso del juego: los rivales bajan un casillero, a veces entra
  /// uno nuevo, y se revisa si chocaste.
  void avanzar() {
    if (terminado) return;

    for (final r in rivales) {
      r.fila++;
    }

    // Los que ya salieron del todo por abajo son los que esquivaste.
    final salieron = rivales.where((r) => r.fila >= filas).length;
    if (salieron > 0) {
      rivales.removeWhere((r) => r.fila >= filas);
      puntaje += salieron * 10;
      nivel = 1 + puntaje ~/ 100;
    }

    _contadorAvances++;
    if (_contadorAvances % avancesEntreRivales == 0) {
      rivales.add(AutoRival(
        carril: _carrilParaElProximoRival(),
        // Entra justo arriba del borde, para que aparezca deslizándose
        // en vez de materializarse de golpe en la pista.
        fila: -altoAuto,
      ));
    }

    _revisarChoque();
  }

  /// Elige el carril del próximo rival.
  ///
  /// No repite el del anterior: al sortear a ciegas salían tandas de
  /// dos y tres autos seguidos por el mismo lado, y eso se siente
  /// injusto -- da la sensación de que el juego te persigue, y encima
  /// deja media pista sin usar.
  int _carrilParaElProximoRival() {
    if (rivales.isEmpty) return _azar.nextInt(carriles);
    final ultimo = rivales.last.carril;
    // Se sortea entre los otros carriles y se corre el resultado para
    // saltear el ocupado, que es la forma de elegir "cualquiera menos
    // ese" sin repetir el sorteo hasta que salga.
    final elegido = _azar.nextInt(carriles - 1);
    return elegido >= ultimo ? elegido + 1 : elegido;
  }

  /// Hay choque si un rival está en tu carril y sus filas se superponen
  /// con las de tu auto.
  void _revisarChoque() {
    for (final r in rivales) {
      if (r.carril != carrilJugador) continue;
      final seSuperponen =
          r.fila <= filas - 1 && r.fila + altoAuto - 1 >= filaJugador;
      if (seSuperponen) {
        terminado = true;
        return;
      }
    }
  }

  /// La pista tal como hay que dibujarla: 0 es vacío, [colorRival] y
  /// [colorJugador] marcan los casilleros de cada auto.
  List<List<int>> vista({required int colorJugador, required int colorRival}) {
    final v = List.generate(filas, (_) => List.filled(columnas, 0));

    void pintar(int carril, int filaTope, int color) {
      for (var i = 0; i < altoAuto; i++) {
        for (var j = 0; j < anchoCarril; j++) {
          if (formaAuto[i][j] == 0) continue;
          final y = filaTope + i;
          if (y < 0 || y >= filas) continue;
          v[y][carril * anchoCarril + j] = color;
        }
      }
    }

    for (final r in rivales) {
      pintar(r.carril, r.fila, colorRival);
    }
    pintar(carrilJugador, filaJugador, colorJugador);
    return v;
  }
}
