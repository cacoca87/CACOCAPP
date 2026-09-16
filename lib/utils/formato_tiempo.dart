/// Formateo de tiempos, en un solo lugar.
///
/// Existe porque la app tenía tres formateadores distintos escritos a
/// mano (el del reproductor, el de los resultados de YouTube y el de
/// Estadísticas) y dos de ellos estaban mal:
///
/// * el del reproductor usaba `inMinutes.remainder(60)`, así que una
///   canción de 1 h 05 min se mostraba como "05:30" -- la hora
///   desaparecía sin dejar rastro. Pasa con los mixes largos y con
///   varios videos de YouTube.
/// * el de Estadísticas redondeaba a minutos enteros, así que todo lo
///   que durara menos de un minuto se leía "0 min", que parece un
///   error de la app y no un dato.
library;

/// Duración de una canción o video, como la muestra cualquier
/// reproductor: `3:05`, y `1:05:30` cuando pasa de la hora.
String duracionCorta(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final horas = total ~/ 3600;
  final minutos = (total % 3600) ~/ 60;
  final segundos = total % 60;
  final ss = segundos.toString().padLeft(2, '0');
  if (horas > 0) return '$horas:${minutos.toString().padLeft(2, '0')}:$ss';
  return '$minutos:$ss';
}

/// Lo mismo pero partiendo de segundos sueltos.
String duracionCortaDeSegundos(int segundos) =>
    duracionCorta(Duration(seconds: segundos));

/// Tiempo acumulado de escucha, en texto largo: `30 s`, `45 min`,
/// `2 h 5 min`.
String tiempoEscuchado(int segundos) {
  if (segundos < 0) segundos = 0;
  if (segundos < 60) return '$segundos s';
  final horas = segundos ~/ 3600;
  final minutos = (segundos % 3600) ~/ 60;
  if (horas > 0) return '$horas h $minutos min';
  return '$minutos min';
}

/// Versión compacta del anterior, para el eje del gráfico de
/// Estadísticas, donde no entra el texto largo: `30s`, `45m`, `2h 5m`.
String tiempoEscuchadoCorto(int segundos) {
  if (segundos < 0) segundos = 0;
  if (segundos < 60) return '${segundos}s';
  final horas = segundos ~/ 3600;
  final minutos = (segundos % 3600) ~/ 60;
  if (horas > 0) return '${horas}h ${minutos}m';
  return '${minutos}m';
}
