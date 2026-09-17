import 'plural.dart';

/// El texto del cartel que aparece al tocar "Actualizar".
///
/// Vive aparte de la pantalla para poder probarlo: son varias
/// combinaciones --con servidor y sin servidor, con música del celular
/// y sin ella, con archivos salteados y sin ellos-- y equivocarse en
/// una es decirle algo falso a la persona.
///
/// POR QUÉ SE CUENTAN LOS ARCHIVOS SALTEADOS
///
/// El filtro que deja afuera las notas de voz de WhatsApp y las
/// grabaciones es una apuesta: decide por la carpeta, el nombre, el
/// formato y la duración. Si algún día se lleva puesta una canción de
/// verdad, no hay ninguna forma de darse cuenta salvo que la app lo
/// diga. Mostrar el número convierte un "me falta un tema" en un "se
/// saltearon 47, alguno era mío".
///
/// El caso que faltaba: cuando NO entró ninguna del celular, el aviso
/// no decía nada --ni siquiera cuántas se saltearon--. Y es justo el
/// peor caso: si el filtro se llevó puesta toda tu música, el cartel
/// se quedaba callado.
/// [hayPermisoDelCelular] es `null` cuando no viene al caso --en una
/// computadora no hay ninguna música del teléfono que leer--, y `false`
/// cuando la persona dijo que no al permiso.
///
/// Ese caso también se decía solo: la app se quedaba sin música del
/// celular para siempre, sin ninguna explicación. El dato lo calculaba
/// el servicio y la pantalla lo tiraba.
String avisoDeActualizacion({
  required bool vinoDelServidor,
  required int delServidor,
  required int delCelular,
  required int salteados,
  bool? hayPermisoDelCelular,
}) {
  final principio = vinoDelServidor
      ? 'Biblioteca actualizada: ${contarCanciones(delServidor)}'
      : 'No se pudo consultar el servidor. Se muestra la lista guardada: '
          '${contarCanciones(delServidor)}';

  final entreParentesis =
      salteados > 0 ? ' (se saltearon $salteados que no son música)' : '';

  if (hayPermisoDelCelular == false) {
    return '$principio · falta el permiso para leer la música de tu celular';
  }
  if (delCelular > 0) {
    return '$principio · ${contarCanciones(delCelular)} del celular'
        '$entreParentesis';
  }
  if (salteados > 0) {
    return '$principio · ninguna del celular$entreParentesis';
  }
  return principio;
}
