/// Leer y guardar el récord de los juegos, en un solo lugar.
///
/// POR QUÉ EXISTE
///
/// Los cuatro juegos (Bloques, Carrera, Serpiente, Disparos) tenían
/// estas mismas treinta líneas copiadas, con un detalle fácil de
/// olvidar: el puntaje nuevo hay que compararlo contra el récord que
/// está EN DISCO, no contra el que la pantalla tiene en memoria.
///
/// El récord se lee del disco al abrir el juego, y esa lectura tarda.
/// Si perdías antes de que terminara --en estos juegos se puede perder
/// en dos segundos-- la pantalla todavía creía que el récord era 0, el
/// puntaje nuevo parecía récord, y se escribía encima del de verdad. O
/// sea: una partida mala te borraba la mejor.
///
/// Eso se arregló una vez, y hubo que arreglarlo en los cuatro
/// archivos. Teniéndolo acá, el quinto juego que se agregue lo hereda
/// bien, y se puede probar con tests --cosa que dentro de una pantalla
/// no se podía--.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// El récord guardado para [clave], o 0 si no hay ninguno.
Future<int> leerRecord(String clave) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(clave) ?? 0;
  } catch (_) {
    // Sin récord guardado se juega igual.
    return 0;
  }
}

/// Guarda [puntaje] como récord de [clave] **solo si supera al que ya
/// está en disco**, y devuelve el récord que quedó vigente.
///
/// Devolverlo (en vez de un `bool`) es lo que deja a la pantalla
/// corregirse sola cuando lo guardado resulta ser mejor que lo que
/// estaba mostrando.
Future<int> guardarRecordSiEsMejor(String clave, int puntaje) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getInt(clave) ?? 0;
    if (puntaje <= guardado) return guardado;
    await prefs.setInt(clave, puntaje);
    return puntaje;
  } catch (_) {
    // No se pudo escribir: al menos que la pantalla muestre lo que
    // acaba de hacer la persona.
    return puntaje;
  }
}
