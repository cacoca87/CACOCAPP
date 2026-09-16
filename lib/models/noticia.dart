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
  String get antiguedad {
    final f = fecha;
    if (f == null) return '';
    final diferencia = DateTime.now().difference(f);
    if (diferencia.isNegative) return 'recién';
    if (diferencia.inMinutes < 1) return 'recién';
    if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
    if (diferencia.inDays == 1) return 'ayer';
    return 'hace ${diferencia.inDays} días';
  }
}
