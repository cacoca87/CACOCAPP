/// Por qué salió bien o mal una descarga, y qué decirle a la persona.
///
/// POR QUÉ NO ALCANZA CON "SALIÓ" / "NO SALIÓ"
///
/// Descargar una canción puede fallar por motivos que no se parecen en
/// nada entre sí, y antes los tres mostraban el mismo cartel: "No se
/// pudo descargar, revisá tu conexión".
///
///  * **Sin señal.** Ahí el mensaje era el correcto.
///  * **El archivo ya no está en el servidor.** La conexión anda
///    perfecto; lo que no está es la canción. Revisar el wifi no
///    arregla nada.
///  * **El celular no tiene espacio.** Es de lo más común en un
///    teléfono de gama media lleno de fotos, y es el peor de los tres:
///    la persona se queda mirando la señal cuando lo que tiene que
///    hacer es borrar cosas.
///
/// Es el mismo tipo de mentira que la app ya arregló en otros lados:
/// un mensaje que suena razonable y manda a la persona a buscar el
/// problema donde no está.
library;

enum ResultadoDeDescarga {
  /// Quedó guardada.
  lista,

  /// Ya estaba descargada de antes. No es un error.
  yaEstaba,

  /// Ya se está bajando ahora mismo. Tampoco es un error.
  yaSeEstaBajando,

  /// No se pudo llegar al servidor.
  sinConexion,

  /// El servidor contestó, pero esa canción no está.
  noEstaEnElServidor,

  /// No se pudo guardar en el teléfono. Casi siempre, falta de espacio.
  noEntraEnElCelular,
}

/// `true` si hay que mostrarlo como error (en rojo).
bool esUnFallo(ResultadoDeDescarga r) =>
    r == ResultadoDeDescarga.sinConexion ||
    r == ResultadoDeDescarga.noEstaEnElServidor ||
    r == ResultadoDeDescarga.noEntraEnElCelular;

/// Qué decirle a la persona. [titulo] es el nombre de la canción.
String mensajeDeDescarga(ResultadoDeDescarga r, String titulo) {
  switch (r) {
    case ResultadoDeDescarga.lista:
      return '"$titulo" descargada ✓';
    case ResultadoDeDescarga.yaEstaba:
      return '"$titulo" ya estaba descargada.';
    case ResultadoDeDescarga.yaSeEstaBajando:
      return '"$titulo" ya se está descargando.';
    case ResultadoDeDescarga.sinConexion:
      return 'No se pudo descargar "$titulo". Revisá tu conexión.';
    case ResultadoDeDescarga.noEstaEnElServidor:
      return 'No se pudo descargar "$titulo": el servidor no la tiene. '
          'No es tu conexión.';
    case ResultadoDeDescarga.noEntraEnElCelular:
      return 'No se pudo guardar "$titulo": parece que no queda espacio '
          'en el celular.';
  }
}
