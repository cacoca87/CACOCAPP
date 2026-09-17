/// Evita que dos pedidos iguales hechos AL MISMO TIEMPO hagan el
/// trabajo dos veces.
///
/// POR QUÉ HACE FALTA
///
/// Todos los cachés de la app siguen la misma forma: "¿lo tengo
/// guardado? lo devuelvo; si no, lo busco y lo guardo". Eso funciona
/// perfecto cuando los pedidos llegan de a uno, y falla justo cuando
/// llegan juntos: los dos miran el caché, los dos lo encuentran vacío,
/// y los dos salen a buscar lo mismo.
///
/// Y en esta app llegan juntos todo el tiempo. La misma canción puede
/// estar dibujada en cuatro lugares a la vez: la fila de la lista, el
/// mini reproductor de abajo, y los carruseles de "Recientes",
/// "Favoritas" y "Recomendado" de la pantalla de Inicio. Las cuatro
/// piden su carátula en el mismo instante, y sin esto son cuatro
/// consultas a internet para traer exactamente la misma dirección.
///
/// Lo que hace es anotar el trabajo que ya está en curso. El segundo
/// que pida lo mismo recibe la MISMA promesa en vez de arrancar otra;
/// cuando termina, la anotación se borra para que la próxima vez se
/// pueda volver a intentar (por ejemplo, si falló por falta de red).
///
/// No reemplaza al caché: lo acompaña. El caché recuerda lo que ya se
/// resolvió; esto evita el trabajo repetido en el hueco de tiempo que
/// va desde que se pide hasta que se guarda.
library;

class UnaSolaVez<T> {
  final Map<String, Future<T>> _enCurso = {};

  /// Cuántos trabajos hay en curso ahora mismo. Para los tests.
  int get enCurso => _enCurso.length;

  /// Corre [trabajo] para [clave], o devuelve el que ya está corriendo
  /// para esa misma clave.
  Future<T> hacer(String clave, Future<T> Function() trabajo) {
    final yaEstaba = _enCurso[clave];
    if (yaEstaba != null) return yaEstaba;

    // `trabajo()` puede fallar antes del primer `await`, y en ese caso
    // lanza acá mismo en vez de devolver una promesa fallada. Con el
    // `Future.sync` el fallo siempre viaja por la promesa, así que el
    // `whenComplete` de abajo corre igual y la anotación no queda
    // trabada para siempre.
    final futuro = Future<T>.sync(trabajo);
    _enCurso[clave] = futuro;
    return futuro.whenComplete(() => _enCurso.remove(clave));
  }
}
