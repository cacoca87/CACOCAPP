/// Controla los reintentos del "refresco de enlace expirado" de
/// YouTube (ver `PlayerProvider`). Aislado en su propia clase, sin
/// streams ni nada async, específicamente para poder testear la
/// lógica que causó el bucle infinito real (décima vuelta, CAMBIOS.md
/// sección 29): dos canciones de YouTube que fallaban a la vez
/// quedaron reintentando para siempre, porque no había ningún tope.
///
/// Regla: cada canción tiene un presupuesto de [maxIntentos] intentos
/// de refresco. Si la reproducción falla para una canción DISTINTA a
/// la que se venía reintentando, el presupuesto arranca de cero para
/// esa canción nueva (no se "hereda" el desgaste de otra canción).
class RefreshRetryGuard {
  final int maxIntentos;

  RefreshRetryGuard({this.maxIntentos = 3});

  String? _cancionActual;
  int _intentos = 0;

  /// Cuántos intentos ya se gastaron para [songId] (0 si es una
  /// canción distinta a la que se está reintentando ahora).
  int intentosPara(String songId) => _cancionActual == songId ? _intentos : 0;

  /// Se llama cuando la reproducción de [songId] está fallando. Si
  /// todavía queda presupuesto, lo consume y devuelve `true` (hay que
  /// intentar un refresco ahora); si ya se agotó, devuelve `false` sin
  /// consumir nada más (hay que rendirse para esta canción).
  bool deberiaReintentar(String songId) {
    if (_cancionActual != songId) {
      _cancionActual = songId;
      _intentos = 0;
    }
    if (_intentos >= maxIntentos) return false;
    _intentos++;
    return true;
  }

  /// Se llama cuando la reproducción vuelve a andar bien, o cuando se
  /// pidió reproducir algo nuevo explícitamente -- deja el presupuesto
  /// de reintentos fresco para la próxima vez que algo falle.
  void reset() {
    _cancionActual = null;
    _intentos = 0;
  }
}
