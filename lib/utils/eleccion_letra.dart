/// Elige cuál de los resultados de lrclib corresponde de verdad a la
/// canción que está sonando.
///
/// Antes se tomaba `resultados.first` a ciegas, y ahí estaba el
/// problema que se vio probando la app: buscar "Amén" de "Amén"
/// devuelve primero **"Refuse Amen" de la banda Amen**, una canción en
/// inglés de 2:47 que no tiene nada que ver con la de 4:13 que estaba
/// sonando. La app mostraba esa letra con total seguridad.
///
/// La duración es el dato que los separa: dos grabaciones distintas
/// casi nunca duran lo mismo. Si se conoce cuánto dura la canción y
/// ningún resultado se le parece, es preferible decir "no se encontró
/// la letra" antes que mostrar la de otra canción.
library;

import 'busqueda.dart';

/// Cuántos segundos de diferencia se toleran entre la canción que suena
/// y la que dice lrclib. Un remaster o un archivo con un silencio al
/// final pueden correrse unos segundos; una canción distinta se corre
/// muchísimo más.
const int toleranciaDeDuracionEnSegundos = 7;

/// Devuelve el resultado elegido, o `null` si no hay ninguno confiable.
///
/// [duracion] es cuánto dura de verdad la canción que está sonando.
/// Cuando no se conoce (por ejemplo, el audio todavía no cargó), no se
/// puede descartar nada y se devuelve el primero, como antes.
///
/// [exigirArtista] obliga a que el artista además coincida. Se usa en
/// la búsqueda que va SOLO por título, y existe por un caso real y
/// vergonzoso: "Amén" de Amén dura 188 segundos, y en la base hay un
/// "AmEN!" de Bring Me the Horizon que dura 189,5. Título parecido y
/// segundo y medio de diferencia: pasó el filtro de duración y la app
/// mostró, con total seguridad, una letra en inglés llena de insultos
/// para una canción de pop-rock peruano. Con el artista de por medio
/// eso no vuelve a pasar.
Map<String, dynamic>? elegirLetraDeLrclib(
  List<dynamic> resultados, {
  Duration? duracion,
  String? artistaBuscado,
  bool exigirArtista = false,
}) {
  final mapas = resultados.whereType<Map<String, dynamic>>().toList();
  if (mapas.isEmpty) return null;

  // Cuando se exige el artista, lo demás no alcanza: primero se
  // descarta todo lo que no sea de ese artista.
  final porArtista = exigirArtista
      ? mapas
          .where((m) => _mismoArtista(m['artistName'], artistaBuscado))
          .toList()
      : mapas;
  if (porArtista.isEmpty) return null;

  final segundosReales = duracion?.inSeconds ?? 0;
  if (segundosReales <= 0) {
    // Sin saber cuánto dura, la duración no puede descartar nada. Pero
    // el artista sí, y conviene usarlo: pasa de verdad que se abra la
    // letra apenas arranca la canción, antes de que el reproductor sepa
    // cuánto dura. Antes, en ese momento se devolvía el primer
    // resultado a ciegas -- que es exactamente la forma del fallo que
    // puso una letra con insultos en pantalla.
    if (artistaBuscado != null && artistaBuscado.trim().isNotEmpty) {
      final delArtista = porArtista
          .where((m) => _mismoArtista(m['artistName'], artistaBuscado))
          .toList();
      if (delArtista.isNotEmpty) return delArtista.first;
    }
    return porArtista.first;
  }

  // Solo se consideran los que dicen cuánto duran; sin ese dato no hay
  // forma de saber si es la canción correcta.
  final conDuracion =
      porArtista.where((m) => _duracionDe(m) != null).toList(growable: false);
  if (conDuracion.isEmpty) return porArtista.first;

  final candidatos = conDuracion
      .where((m) =>
          (_duracionDe(m)! - segundosReales).abs() <=
          toleranciaDeDuracionEnSegundos)
      .toList();
  if (candidatos.isEmpty) return null;

  // Entre los que duran lo mismo, gana el del artista que coincide: en
  // una búsqueda solo por título pueden aparecer varias versiones.
  final delArtista = candidatos
      .where((m) => _mismoArtista(m['artistName'], artistaBuscado))
      .toList();
  final finalistas = delArtista.isNotEmpty ? delArtista : candidatos;

  finalistas.sort((a, b) => (_duracionDe(a)! - segundosReales)
      .abs()
      .compareTo((_duracionDe(b)! - segundosReales).abs()));
  return finalistas.first;
}

/// lrclib manda la duración en segundos, a veces con decimales.
int? _duracionDe(Map<String, dynamic> resultado) {
  final valor = resultado['duration'];
  if (valor is num && valor > 0) return valor.round();
  return null;
}

/// Compara artistas **ignorando las tildes**, no solo las mayúsculas.
///
/// Sin eso, "Amén" y "Amen" son dos artistas distintos para la
/// computadora, y la base de letras rara vez escribe los nombres con
/// las tildes puestas. El resultado era el peor posible: la regla del
/// artista --la que existe justamente para que no se cuele una letra
/// ajena-- rechazaba la letra CORRECTA de "Amén" porque en lrclib
/// figura como "Amen".
bool _mismoArtista(dynamic delResultado, String? buscado) {
  if (delResultado is! String || buscado == null) return false;
  final a = paraBuscar(delResultado.trim());
  final b = paraBuscar(buscado.trim());
  if (a.isEmpty || b.isEmpty) return false;
  return a == b || a.contains(b) || b.contains(a);
}
