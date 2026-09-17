import 'formato_tiempo.dart';

/// Qué mostrar en la barra de progreso del reproductor.
///
/// EL PROBLEMA QUE ARREGLA
///
/// Mientras no se sabe cuánto dura la canción, el reproductor **hacía
/// de cuenta que duraba tres minutos**. Eso trae tres cosas, todas
/// visibles:
///
///  1. Abajo a la derecha decía `3:00`, que es un dato inventado.
///  2. En una canción más larga, la barra llegaba al final a los tres
///     minutos y se quedaba clavada ahí mientras la canción seguía
///     sonando.
///  3. Arrastrando la barra no se podía pasar de los tres minutos: el
///     resto de la canción quedaba fuera de alcance.
///
/// No hace falta una conexión mala para verlo: la duración de cualquier
/// canción tarda un momento en conocerse, y con una canción del
/// servidor en una red lenta ese momento dura bastante.
///
/// Lo que hace cualquier reproductor de verdad es lo que se hace ahora:
/// mientras no se sabe, se muestra `--:--` y la barra no se puede
/// arrastrar. Es menos bonito que una barra que se mueve, y es cierto.
class BarraDeProgreso {
  /// Dónde va el punto de la barra.
  final double valor;

  /// El final de la barra. Nunca cero: un `Slider` con `min == max`
  /// tira un error.
  final double maximo;

  /// `false` mientras no se sepa cuánto dura: arrastrar no tendría
  /// contra qué.
  final bool sePuedeArrastrar;

  /// El tiempo que va, abajo a la izquierda.
  final String textoIzquierda;

  /// Lo que dura, abajo a la derecha. `--:--` mientras no se sepa.
  final String textoDerecha;

  const BarraDeProgreso({
    required this.valor,
    required this.maximo,
    required this.sePuedeArrastrar,
    required this.textoIzquierda,
    required this.textoDerecha,
  });
}

/// [valorMientrasArrastra] es lo que el dedo está marcando ahora, o
/// `null` si nadie está arrastrando. Mientras se arrastra se muestra
/// ESE valor y no el de la reproducción: si no, cada aviso de posición
/// --unas cinco veces por segundo-- le pisaría el arrastre a mitad de
/// camino y la barra pelearía contra el dedo.
BarraDeProgreso calcularBarraDeProgreso({
  required Duration posicion,
  required Duration? duracion,
  double? valorMientrasArrastra,
}) {
  final seSabeCuantoDura = duracion != null && duracion.inMilliseconds > 0;

  if (!seSabeCuantoDura) {
    return BarraDeProgreso(
      valor: 0,
      maximo: 1,
      sePuedeArrastrar: false,
      // El tiempo que va SÍ se sabe, así que se muestra: es lo único
      // cierto que hay para mostrar en ese momento.
      textoIzquierda: duracionCorta(_sinNegativos(posicion)),
      textoDerecha: '--:--',
    );
  }

  final maximo = duracion.inMilliseconds.toDouble();
  final valorReal =
      _sinNegativos(posicion).inMilliseconds.toDouble().clamp(0.0, maximo);
  final valor = (valorMientrasArrastra ?? valorReal).clamp(0.0, maximo);

  return BarraDeProgreso(
    valor: valor,
    maximo: maximo,
    sePuedeArrastrar: true,
    textoIzquierda: duracionCorta(Duration(milliseconds: valor.toInt())),
    textoDerecha: duracionCorta(duracion),
  );
}

/// La posición puede venir negativa un instante al saltar hacia atrás.
Duration _sinNegativos(Duration d) => d.isNegative ? Duration.zero : d;
