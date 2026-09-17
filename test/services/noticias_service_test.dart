import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:CACOCAPP/services/noticias_service.dart';

const _feed = '''
<rss><channel>
  <item>
    <title>Suben los fletes marítimos hacia Asia - Gestión</title>
    <link>https://news.google.com/a</link>
    <source url="https://gestion.pe">Gestión</source>
  </item>
</channel></rss>''';

const _categoria = CategoriaNoticias('Logística', 'logística');

void main() {
  group('NoticiasService', () {
    test('trae y parsea las noticias', () async {
      final servicio = NoticiasService.testable(
        MockClient((_) async => http.Response.bytes(utf8.encode(_feed), 200)),
      );
      final noticias = await servicio.obtener(_categoria);
      expect(noticias.length, 1);
      expect(noticias.first.fuente, 'Gestión');
    });

    test('pide el feed en español', () async {
      Uri? pedida;
      final servicio = NoticiasService.testable(MockClient((req) async {
        pedida = req.url;
        return http.Response.bytes(utf8.encode(_feed), 200);
      }));
      await servicio.obtener(_categoria);
      expect(pedida!.host, 'news.google.com');
      expect(pedida!.queryParameters['q'], 'logística');
      expect(pedida!.queryParameters['hl'], startsWith('es'));
    });

    test('los acentos y las eñes llegan bien', () async {
      // Se leen los bytes como UTF-8 a propósito: tomando `body` directo,
      // "Gestión" llegaría como "GestiÃ³n".
      final servicio = NoticiasService.testable(
        MockClient((_) async => http.Response.bytes(utf8.encode(_feed), 200)),
      );
      final noticias = await servicio.obtener(_categoria);
      expect(noticias.first.fuente, 'Gestión');
      expect(noticias.first.titulo, contains('marítimos'));
    });

    test('sin internet avisa que es la conexión, no un error del servidor',
        () async {
      final servicio = NoticiasService.testable(
        MockClient((_) async => throw const SocketException('sin red')),
      );
      await expectLater(
        servicio.obtener(_categoria),
        throwsA(isA<ErrorNoticias>()
            .having((e) => e.sinConexion, 'sinConexion', isTrue)),
      );
    });

    test('un tiempo de espera agotado también cuenta como problema de red',
        () async {
      final servicio = NoticiasService.testable(
        MockClient((_) async => throw TimeoutException('lento')),
      );
      await expectLater(
        servicio.obtener(_categoria),
        throwsA(isA<ErrorNoticias>()
            .having((e) => e.sinConexion, 'sinConexion', isTrue)),
      );
    });

    test('un error del servidor NO se reporta como falta de conexión',
        () async {
      final servicio = NoticiasService.testable(
        MockClient((_) async => http.Response('', 503)),
      );
      await expectLater(
        servicio.obtener(_categoria),
        throwsA(isA<ErrorNoticias>()
            .having((e) => e.sinConexion, 'sinConexion', isFalse)),
      );
    });

    test('una respuesta que no es un feed avisa en vez de mostrar vacío',
        () async {
      final servicio = NoticiasService.testable(
        MockClient((_) async =>
            http.Response.bytes(utf8.encode('<html>error</html>'), 200)),
      );
      await expectLater(
        servicio.obtener(_categoria),
        throwsA(isA<ErrorNoticias>()),
      );
    });

    test('un feed valido pero sin noticias NO es un error', () async {
      // Google Noticias contesta un feed bien formado y vacio cuando la
      // busqueda no encuentra nada. Antes eso se lanzaba como error y
      // se veia igual que "se cayo el servidor".
      const vacio = '<rss><channel></channel></rss>';
      final servicio = NoticiasService.testable(
        MockClient((_) async => http.Response.bytes(utf8.encode(vacio), 200)),
      );
      expect(await servicio.obtener(_categoria), isEmpty);
    });

    test('un resultado vacio no se guarda en cache', () async {
      // Si se guardara, "Reintentar" devolveria el vacio guardado sin
      // volver a preguntar nunca.
      var llamadas = 0;
      final servicio = NoticiasService.testable(MockClient((_) async {
        llamadas++;
        return http.Response.bytes(
            utf8.encode('<rss><channel></channel></rss>'), 200);
      }));
      await servicio.obtener(_categoria);
      await servicio.obtener(_categoria);
      expect(llamadas, 2);
    });

    test('la caché evita volver a pedir lo mismo', () async {
      var llamadas = 0;
      final servicio = NoticiasService.testable(MockClient((_) async {
        llamadas++;
        return http.Response.bytes(utf8.encode(_feed), 200);
      }));

      await servicio.obtener(_categoria);
      await servicio.obtener(_categoria);
      expect(llamadas, 1);

      // Deslizar para actualizar sí tiene que volver a pedirlo.
      await servicio.obtener(_categoria, forzar: true);
      expect(llamadas, 2);
    });

    test('un fallo inesperado también llega como ErrorNoticias', () async {
      // La pantalla solo atrapa `ErrorNoticias`. Antes, cualquier
      // excepción que no fuera de los tres tipos previstos (sin red,
      // lento, cliente HTTP) se le escapaba, y la ruedita de "cargando"
      // se quedaba girando para siempre sin decir qué había pasado.
      // Un fallo de certificado, por ejemplo, no es ninguno de los tres.
      final servicio = NoticiasService.testable(
        MockClient((_) async => throw const HandshakeException('certificado')),
      );
      await expectLater(
        servicio.obtener(_categoria),
        throwsA(isA<ErrorNoticias>()),
      );
    });

    test('un error con mensaje propio no se pierde al envolverlo', () async {
      // El `catch` general no tiene que comerse los errores que ya
      // traen su explicación escrita.
      final servicio = NoticiasService.testable(
        MockClient((_) async => http.Response('', 503)),
      );
      await expectLater(
        servicio.obtener(_categoria),
        throwsA(isA<ErrorNoticias>()
            .having((e) => e.mensaje, 'mensaje', contains('503'))),
      );
    });

    test('están las siete categorías que pidió el profesor, más música', () {
      final nombres = NoticiasService.categorias.map((c) => c.nombre).toList();
      expect(nombres, contains('Negocios internacionales'));
      expect(nombres, contains('Comercio global'));
      expect(nombres, contains('Logística'));
      expect(nombres, contains('Cadena de suministro'));
      expect(nombres, contains('Contratos'));
      expect(nombres, contains('Tecnología'));
      expect(nombres, contains('Música'));
    });
  });
}
