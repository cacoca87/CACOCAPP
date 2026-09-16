import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/rss_parser.dart';

/// Recorte real del formato que devuelve el RSS de Google Noticias.
const _rssDeEjemplo = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>logística - Google Noticias</title>
    <item>
      <title>El puerto del Callao amplía su capacidad de contenedores - El Comercio</title>
      <link>https://news.google.com/articulo1</link>
      <pubDate>Mon, 15 Sep 2026 14:30:00 GMT</pubDate>
      <source url="https://elcomercio.pe">El Comercio</source>
    </item>
    <item>
      <title>Nuevas reglas para contratos de exportación - Gestión</title>
      <link>https://news.google.com/articulo2</link>
      <pubDate>Tue, 16 Sep 2026 08:05:00 GMT</pubDate>
      <source url="https://gestion.pe">Gestión</source>
    </item>
  </channel>
</rss>
''';

void main() {
  group('parsearRss', () {
    test('lee todas las noticias del feed', () {
      final noticias = parsearRss(_rssDeEjemplo);
      expect(noticias.length, 2);
    });

    test('lee título, enlace y fuente', () {
      final n = parsearRss(_rssDeEjemplo).first;
      expect(
          n.titulo, 'El puerto del Callao amplía su capacidad de contenedores');
      expect(n.enlace, 'https://news.google.com/articulo1');
      expect(n.fuente, 'El Comercio');
    });

    test('saca el nombre del medio repetido al final del título', () {
      // Google Noticias agrega " - Medio" a cada titular. Como el medio
      // ya se muestra aparte, dejarlo sería repetir la información.
      final noticias = parsearRss(_rssDeEjemplo);
      expect(noticias[0].titulo, isNot(contains('El Comercio')));
      expect(noticias[1].titulo, 'Nuevas reglas para contratos de exportación');
    });

    test('no recorta un guion que es parte del titular', () {
      const xml = '''
<rss><channel><item>
  <title>Acuerdo Perú - Estados Unidos entra en vigencia mañana por la tarde</title>
  <link>https://ejemplo.test/a</link>
</item></channel></rss>''';
      final n = parsearRss(xml).first;
      expect(n.titulo, contains('Estados Unidos entra en vigencia'));
    });

    test('entiende las fechas en formato RFC 822', () {
      final n = parsearRss(_rssDeEjemplo).first;
      expect(n.fecha, isNotNull);
      expect(n.fecha!.toUtc().year, 2026);
      expect(n.fecha!.toUtc().month, 9);
      expect(n.fecha!.toUtc().day, 15);
      expect(n.fecha!.toUtc().hour, 14);
    });

    test('una fecha ilegible no rompe la noticia', () {
      const xml = '''
<rss><channel><item>
  <title>Titular</title>
  <link>https://ejemplo.test/a</link>
  <pubDate>vaya uno a saber</pubDate>
</item></channel></rss>''';
      final n = parsearRss(xml).first;
      expect(n.titulo, 'Titular');
      expect(n.fecha, isNull);
    });

    test('descarta las entradas sin título o sin enlace', () {
      const xml = '''
<rss><channel>
  <item><title>Sin enlace</title></item>
  <item><link>https://ejemplo.test/sin-titulo</link></item>
  <item><title>Completa</title><link>https://ejemplo.test/ok</link></item>
</channel></rss>''';
      final noticias = parsearRss(xml);
      expect(noticias.length, 1);
      expect(noticias.first.titulo, 'Completa');
    });

    test('un XML roto devuelve lista vacía en vez de reventar', () {
      // Pasa de verdad: a veces el servidor responde una página de error
      // en HTML con el mismo código 200.
      expect(parsearRss('<html><body>Error 500</body></html>'), isEmpty);
      expect(parsearRss('esto no es xml'), isEmpty);
      expect(parsearRss(''), isEmpty);
    });

    test('respeta el límite de noticias', () {
      final xml = StringBuffer('<rss><channel>');
      for (var i = 0; i < 50; i++) {
        xml.write(
            '<item><title>N$i</title><link>https://e.test/$i</link></item>');
      }
      xml.write('</channel></rss>');
      expect(parsearRss(xml.toString(), limite: 10).length, 10);
    });

    test('un feed sin <source> deja la fuente vacía, no rompe', () {
      const xml = '''
<rss><channel><item>
  <title>Titular suelto</title>
  <link>https://ejemplo.test/a</link>
</item></channel></rss>''';
      expect(parsearRss(xml).first.fuente, '');
    });
  });

  group('Noticia.antiguedad', () {
    test('muestra minutos, horas y días según corresponda', () {
      final ahora = DateTime.now();
      String antiguedadDe(Duration d) => parsearRss('''
<rss><channel><item>
  <title>T</title><link>https://e.test/a</link>
  <pubDate>${_rfc822(ahora.subtract(d))}</pubDate>
</item></channel></rss>''').first.antiguedad;

      expect(antiguedadDe(const Duration(minutes: 5)), contains('min'));
      expect(antiguedadDe(const Duration(hours: 3)), contains('h'));
      expect(antiguedadDe(const Duration(days: 1)), 'ayer');
      expect(antiguedadDe(const Duration(days: 4)), contains('días'));
    });
  });
}

String _rfc822(DateTime f) {
  const meses = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final u = f.toUtc();
  final dia = u.day.toString().padLeft(2, '0');
  final hh = u.hour.toString().padLeft(2, '0');
  final mm = u.minute.toString().padLeft(2, '0');
  return 'Mon, $dia ${meses[u.month - 1]} ${u.year} $hh:$mm:00 GMT';
}
