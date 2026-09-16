import 'package:xml/xml.dart';
import '../models/noticia.dart';

/// Convierte el XML de un feed RSS en una lista de noticias, o
/// devuelve `null` si lo que llegó NO es un feed.
///
/// La diferencia importa: `null` es "el servidor devolvió cualquier
/// cosa" (XML roto, o una página de error HTML mandada con código 200)
/// y eso es un error que hay que avisar; una lista vacía es un feed
/// perfectamente válido que hoy no trae noticias de ese tema, que no
/// es un error. Antes los dos casos eran la misma lista vacía.
///
/// Vive aparte del servicio, y sin nada de red adentro, para poder
/// probarlo con XML de ejemplo -- mismo criterio que
/// `lyrics_parsing.dart` o `nombre_archivo_parser.dart`. Es el pedazo
/// más frágil de la sección: el día que Google Noticias cambie algo del
/// formato, los tests de acá son los que lo van a delatar.
List<Noticia>? parsearRssONulo(String xml, {int limite = 30}) {
  final XmlDocument documento;
  try {
    documento = XmlDocument.parse(xml);
  } catch (_) {
    // XML roto.
    return null;
  }

  // Una página de error HTML también es XML válido, así que no alcanza
  // con que haya parseado: la raíz tiene que ser la de un feed.
  const raicesDeFeed = {'rss', 'feed', 'rdf'};
  if (!raicesDeFeed.contains(documento.rootElement.name.local.toLowerCase())) {
    return null;
  }

  final noticias = <Noticia>[];
  for (final item in documento.findAllElements('item')) {
    final titulo = _texto(item, 'title');
    final enlace = _texto(item, 'link');
    if (titulo.isEmpty || enlace.isEmpty) continue;

    noticias.add(Noticia(
      titulo: _limpiarTitulo(titulo),
      enlace: enlace,
      fuente: _fuente(item),
      fecha: _fecha(_texto(item, 'pubDate')),
    ));
    if (noticias.length >= limite) break;
  }
  return noticias;
}

/// Igual que [parsearRssONulo] pero tratando "no es un feed" como una
/// lista vacía. Lo usan los tests del parser, a los que solo les
/// importa qué noticias salen.
List<Noticia> parsearRss(String xml, {int limite = 30}) =>
    parsearRssONulo(xml, limite: limite) ?? const [];

String _texto(XmlElement item, String etiqueta) {
  final encontrados = item.findElements(etiqueta);
  if (encontrados.isEmpty) return '';
  return encontrados.first.innerText.trim();
}

/// Google Noticias pone el medio en `<source>`; otros feeds no lo traen
/// y ahí se deja vacío, que la pantalla resuelve no mostrando nada.
String _fuente(XmlElement item) {
  final fuente = _texto(item, 'source');
  if (fuente.isNotEmpty) return fuente;
  return _texto(item, 'dc:creator');
}

/// Google Noticias repite el medio al final del título, separado por un
/// guion largo: "Titular de la noticia - El Comercio". Se saca porque el
/// medio ya se muestra aparte, y si no el título queda con la misma
/// información dos veces.
String _limpiarTitulo(String titulo) {
  final corte = titulo.lastIndexOf(' - ');
  if (corte <= 0) return titulo;
  final posibleFuente = titulo.substring(corte + 3).trim();
  // Solo se recorta si lo de después del guion parece un nombre de medio
  // (corto y sin puntuación de oración), no parte del titular.
  if (posibleFuente.length > 40 || posibleFuente.contains('.')) return titulo;
  return titulo.substring(0, corte).trim();
}

/// Las fechas de RSS vienen en formato RFC 822
/// ("Mon, 15 Sep 2026 14:30:00 GMT"), que `DateTime.parse` no entiende.
DateTime? _fecha(String texto) {
  if (texto.isEmpty) return null;

  const meses = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  // "Mon, 15 Sep 2026 14:30:00 GMT" -> partes tras sacar el día de semana
  final patron = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?',
  );
  final m = patron.firstMatch(texto);
  if (m == null) return null;

  final mes = meses[m.group(2)!.toLowerCase()];
  if (mes == null) return null;

  try {
    return DateTime.utc(
      int.parse(m.group(3)!),
      mes,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6) ?? '0'),
    ).toLocal();
  } catch (_) {
    return null;
  }
}
