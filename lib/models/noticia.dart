/// Una noticia de la sección Noticias.
class Noticia {
  final String titulo;
  final String enlace;
  final String fuente;
  final DateTime? fecha;

  const Noticia({
    required this.titulo,
    required this.enlace,
    required this.fuente,
    this.fecha,
  });

  /// Texto corto tipo "hace 3 h" para mostrar al lado de la fuente. Se
  /// prefiere esto a la fecha exacta porque en noticias lo que importa
  /// es qué tan reciente es, no el día concreto.
  String get antiguedad => antiguedadDesde(DateTime.now());

  /// La misma cuenta, pero diciéndole desde cuándo se mira.
  ///
  /// Existe para poder probarla: con `DateTime.now()` adentro, un test
  /// tendría que esperar horas de verdad para comprobar que dice "hace
  /// 3 h".
  String antiguedadDesde(DateTime ahora) {
    final f = fecha;
    if (f == null) return '';
    final diferencia = ahora.difference(f);
    // Una noticia "del futuro" pasa: el reloj del celular puede estar
    // atrasado respecto del servidor. Decir "hace -2 h" quedaría peor
    // que no decir la hora exacta.
    if (diferencia.isNegative) return 'recién';
    if (diferencia.inMinutes < 1) return 'recién';
    if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
    if (diferencia.inDays == 1) return 'ayer';
    // Más de un mes: el número de días deja de decir algo útil ("hace
    // 213 días" no se lee, se calcula). Las noticias viejas casi nunca
    // aparecen, pero cuando aparecen conviene que se entiendan.
    if (diferencia.inDays >= 30) {
      final meses = diferencia.inDays ~/ 30;
      return meses == 1 ? 'hace un mes' : 'hace $meses meses';
    }
    return 'hace ${diferencia.inDays} días';
  }
}
