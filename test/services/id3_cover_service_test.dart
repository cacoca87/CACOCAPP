import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:CACOCAPP/services/id3_cover_service.dart';

/// Reemplaza la carpeta temporal real de Android por una de verdad en
/// el disco de la máquina donde corren los tests. Hace falta porque lo
/// que se está probando es justamente QUÉ archivos deja escritos el
/// servicio: sin esto, las escrituras fallarían en silencio y el test
/// pasaría sin comprobar nada.
class _CarpetaFalsa extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _CarpetaFalsa(this.raiz);
  final String raiz;

  @override
  Future<String?> getTemporaryPath() async => raiz;
}

/// Arma un MP3 mínimo de verdad: una etiqueta ID3v2.3 con un cuadro
/// APIC (la carátula incrustada) adentro.
///
/// Se construye a mano, byte por byte, en vez de meter un MP3 de
/// ejemplo en el repositorio: así el test dice explícitamente qué
/// formato se está leyendo, y no depende de un archivo binario que
/// nadie puede revisar.
List<int> _mp3ConTapa({List<int> imagen = const [0xFF, 0xD8, 0xFF, 0xD9]}) {
  // Cuerpo del cuadro APIC, tal como lo define ID3v2.3.
  final cuerpo = <int>[
    0x00, // codificación del texto: ISO-8859-1
    ...'image/jpeg'.codeUnits, 0x00, // tipo de imagen, terminado en cero
    0x03, // 3 = "tapa del frente"
    0x00, // descripción vacía, terminada en cero
    ...imagen,
  ];

  // Cabecera del cuadro: identificador, tamaño (32 bits) y dos banderas.
  final cuadro = <int>[
    ...'APIC'.codeUnits,
    (cuerpo.length >> 24) & 0xFF,
    (cuerpo.length >> 16) & 0xFF,
    (cuerpo.length >> 8) & 0xFF,
    cuerpo.length & 0xFF,
    0x00,
    0x00,
    ...cuerpo,
  ];

  // El tamaño de la etiqueta va "sincroseguro": siete bits por byte.
  final n = cuadro.length;
  final etiqueta = <int>[
    ...'ID3'.codeUnits,
    0x03, 0x00, // versión 2.3
    0x00, // sin banderas
    (n >> 21) & 0x7F,
    (n >> 14) & 0x7F,
    (n >> 7) & 0x7F,
    n & 0x7F,
    ...cuadro,
  ];

  // Un poco de relleno detrás, como tendría el audio de verdad.
  return [...etiqueta, ...List<int>.filled(64, 0)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory raiz;
  late Directory carpetaDeCache;

  setUp(() async {
    raiz = await Directory.systemTemp.createTemp('cacocapp_id3_test');
    PathProviderPlatform.instance = _CarpetaFalsa(raiz.path);
    carpetaDeCache = Directory('${raiz.path}/id3_covers');
  });

  tearDown(() async {
    if (await raiz.exists()) await raiz.delete(recursive: true);
  });

  const url = 'https://ejemplo.test/Roxanne.mp3';
  // El nombre que el servicio le da a sus archivos sale del último
  // segmento de la URL.
  const clave = 'Roxanne.mp3';

  Future<bool> existeMarca(String extension) =>
      File('${carpetaDeCache.path}/$clave.$extension').exists();

  /// Las marcas se escriben sin esperar (a propósito: no tienen que
  /// frenar la pantalla), así que hay que darles un instante antes de
  /// mirar el disco.
  Future<void> esperarEscrituras() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  group('Id3CoverService: no confundir "no hay" con "no pude leerlo"', () {
    test('sin internet NO deja la canción marcada como "sin carátula"',
        () async {
      // Este era el fallo más grave de toda la app: abrirla una sola vez
      // con mala señal dejaba cientos de canciones marcadas en el disco
      // como "sin carátula" y "Artista Desconocido" PARA SIEMPRE,
      // aunque el MP3 sí trajera esos datos.
      final servicio = Id3CoverService.testable(
        MockClient((_) async => throw const SocketException('sin red')),
      );

      expect(await servicio.getEmbeddedCover(url), isNull);
      await esperarEscrituras();
      expect(await existeMarca('nocover'), isFalse,
          reason: 'un fallo de red no puede quedar escrito como definitivo');
    });

    test('un error del servidor tampoco deja la marca', () async {
      final servicio = Id3CoverService.testable(
        MockClient((_) async => http.Response('', 503)),
      );

      expect(await servicio.getEmbeddedCover(url), isNull);
      await esperarEscrituras();
      expect(await existeMarca('nocover'), isFalse);
    });

    test('un archivo que SÍ se pudo leer y no trae tags sí deja la marca',
        () async {
      // Acá la respuesta llegó entera: que no tenga carátula es un dato
      // definitivo y vale la pena anotarlo para no volver a bajar 512 KB
      // cada vez.
      final servicio = Id3CoverService.testable(
        MockClient((_) async => http.Response.bytes(
              List<int>.filled(2048, 0),
              206,
            )),
      );

      expect(await servicio.getEmbeddedCover(url), isNull);
      await esperarEscrituras();
      expect(await existeMarca('nocover'), isTrue);
    });

    test('lo mismo para el álbum y el artista', () async {
      final sinRed = Id3CoverService.testable(
        MockClient((_) async => throw const SocketException('sin red')),
      );
      expect(await sinRed.getEmbeddedAlbum(url), isNull);
      expect(await sinRed.getEmbeddedArtist(url), isNull);
      await esperarEscrituras();
      expect(await existeMarca('noalbum'), isFalse);
      expect(await existeMarca('noartist'), isFalse);

      final conRed = Id3CoverService.testable(
        MockClient(
            (_) async => http.Response.bytes(List<int>.filled(2048, 0), 206)),
      );
      expect(await conRed.getEmbeddedAlbum(url), isNull);
      await esperarEscrituras();
      expect(await existeMarca('noalbum'), isTrue);
    });

    test('una vez marcada, no vuelve a pedirla por red', () async {
      var llamadas = 0;
      final primera = Id3CoverService.testable(MockClient((_) async {
        llamadas++;
        return http.Response.bytes(List<int>.filled(2048, 0), 206);
      }));
      await primera.getEmbeddedCover(url);
      await esperarEscrituras();
      expect(llamadas, 1);

      // Sesión nueva: la marca en disco evita el pedido.
      final segunda = Id3CoverService.testable(MockClient((_) async {
        llamadas++;
        return http.Response.bytes(List<int>.filled(2048, 0), 206);
      }));
      expect(await segunda.getEmbeddedCover(url), isNull);
      expect(llamadas, 1);
    });

    test('una marca vieja de "sin carátula" se descarta y se vuelve a pedir',
        () async {
      // Lo importante de la corrección: la regla nueva no sirve de nada
      // si lo que quedó mal escrito en el celular se sigue leyendo.
      await carpetaDeCache.create(recursive: true);
      await File('${carpetaDeCache.path}/$clave.nocover')
          .writeAsBytes(const []);
      await File('${carpetaDeCache.path}/$clave.noartist')
          .writeAsBytes(const []);

      var pidio = false;
      final servicio = Id3CoverService.testable(MockClient((_) async {
        pidio = true;
        return http.Response.bytes(List<int>.filled(2048, 0), 206);
      }));

      await servicio.getEmbeddedCover(url);
      expect(pidio, isTrue,
          reason: 'la marca vieja no puede seguir tapando la consulta');
    });

    test('una carátula ya guardada NO se borra: volver a bajarla gasta datos',
        () async {
      await carpetaDeCache.create(recursive: true);
      final guardada = File('${carpetaDeCache.path}/$clave.jpg');
      await guardada.writeAsBytes(const [1, 2, 3]);
      await File('${carpetaDeCache.path}/$clave.nocover')
          .writeAsBytes(const []);

      var pidio = false;
      final servicio = Id3CoverService.testable(MockClient((_) async {
        pidio = true;
        return http.Response.bytes(List<int>.filled(2048, 0), 206);
      }));

      expect(await servicio.getEmbeddedCover(url), [1, 2, 3]);
      expect(pidio, isFalse);
      expect(await guardada.exists(), isTrue);
    });

    test('la ruta de la carátula llega ya escrita, no a medio escribir',
        () async {
      // Lo usa la notificación de la pantalla de bloqueo, que necesita
      // un archivo de verdad (no bytes sueltos) para mostrar la tapa.
      //
      // Acá había una carrera: los bytes se guardaban en disco SIN
      // esperar la escritura, y enseguida se comprobaba si el archivo
      // existía. Casi siempre la comprobación llegaba primero, así que
      // la primera vez que ponías una canción la respuesta era `null`
      // y la tapa del bloqueo se buscaba en iTunes -- un pedido de red
      // de más, para conseguir una imagen que ya estaba adentro del
      // propio MP3.
      final servicio = Id3CoverService.testable(
        MockClient((_) async => http.Response.bytes(_mp3ConTapa(), 206)),
      );

      final ruta = await servicio.getEmbeddedCoverPath(url);
      expect(ruta, isNotNull,
          reason: 'la ruta tiene que venir con el archivo ya escrito');
      expect(await File(ruta!).exists(), isTrue);
      expect((await File(ruta).readAsBytes()).isNotEmpty, isTrue);
    });

    test('dos pedidos a la vez comparten UNA sola descarga', () async {
      // Al abrir la app pasan dos cosas al mismo tiempo: la lista pide
      // la carátula de cada canción que se ve, y por detrás corre el
      // repaso que completa el álbum y el artista de toda la
      // biblioteca. Las dos necesitan los mismos 512 KB del mismo MP3.
      //
      // Cada una los bajaba por su cuenta: el doble de datos móviles,
      // por nada. Con decenas de canciones en pantalla, varios megas de
      // más en el primer arranque.
      var descargas = 0;
      final servicio = Id3CoverService.testable(MockClient((_) async {
        descargas++;
        // Un ratito, para que el segundo pedido llegue de verdad
        // mientras el primero sigue en la red.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response.bytes(_mp3ConTapa(), 206);
      }));

      // A propósito SIN await entre medio: se piden los dos juntos.
      final resultados = await Future.wait([
        servicio.getEmbeddedCoverPath(url),
        servicio.getEmbeddedAlbum(url),
      ]);

      expect(descargas, 1, reason: 'el mismo MP3 no se baja dos veces');
      expect(resultados.first, isNotNull);
    });

    test('cuatro filas pidiendo la misma tapa hacen el trabajo una vez',
        () async {
      // La canción que suena puede estar dibujada a la vez en la fila
      // de la lista, en el mini reproductor de abajo y en dos
      // carruseles de Inicio. Las cuatro piden su tapa en el mismo
      // instante: sin juntarlas, eran cuatro descargas, cuatro lecturas
      // de medio megabyte y cuatro escrituras del mismo archivo.
      var descargas = 0;
      final servicio = Id3CoverService.testable(MockClient((_) async {
        descargas++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response.bytes(_mp3ConTapa(), 206);
      }));

      final rutas = await Future.wait(List.generate(
        4,
        (_) => servicio.getEmbeddedCoverPath(url),
      ));

      expect(descargas, 1);
      // Y todas apuntan al mismo archivo, no a cuatro copias.
      expect(rutas.whereType<String>().toSet().length, 1);
    });

    test('una canción DESCARGADA lee su tapa del archivo, sin tocar internet',
        () async {
      // La app guarda la dirección de una canción descargada como
      // `file:///...`, y así le llega acá. Eso es una dirección, no una
      // ruta: se le pasaba tal cual a `File`, que armaba un archivo
      // llamado literalmente "file:///data/..." y por supuesto no
      // existía. La comprobación decía "no está" sin quejarse.
      //
      // Resultado: las canciones descargadas se quedaban sin su
      // carátula en la pantalla de bloqueo y la app salía a buscarla a
      // internet -- justo lo contrario de para qué se descarga una
      // canción.
      final descargada = File('${raiz.path}/Descargada.mp3');
      await descargada.writeAsBytes(_mp3ConTapa());
      final direccion = Uri.file(descargada.path).toString();

      var fueALaRed = false;
      final servicio = Id3CoverService.testable(MockClient((_) async {
        fueALaRed = true;
        return http.Response('', 500);
      }));

      final ruta = await servicio.getEmbeddedCoverPath(direccion);

      expect(ruta, isNotNull, reason: 'la tapa estaba adentro del archivo');
      expect(fueALaRed, isFalse,
          reason: 'una canción descargada no tiene por qué usar internet');
    });

    test('la limpieza se hace una sola vez', () async {
      await carpetaDeCache.create(recursive: true);
      final servicio = Id3CoverService.testable(
        MockClient((_) async => http.Response('', 503)),
      );
      await servicio.getEmbeddedCover(url);
      await esperarEscrituras();

      // Una marca escrita DESPUÉS de la limpieza tiene que sobrevivir:
      // si no, la app volvería a pedir lo mismo en cada apertura.
      final marcaNueva = File('${carpetaDeCache.path}/otra.mp3.nocover');
      await marcaNueva.writeAsBytes(const []);
      final otro = Id3CoverService.testable(
        MockClient((_) async => http.Response('', 503)),
      );
      await otro.getEmbeddedCover('https://ejemplo.test/otra.mp3');
      expect(await marcaNueva.exists(), isTrue);
    });
  });
}
