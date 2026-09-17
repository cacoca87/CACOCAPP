import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CACOCAPP/services/drive_service.dart';

/// Lo que devuelve el Worker: una lista de objetos con el nombre del
/// archivo.
String _respuesta(List<String> nombres) => jsonEncode([
      for (final n in nombres) {'name': n}
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('DriveService', () {
    test('arma las canciones con lo que manda el servidor', () async {
      final servicio = DriveService(
        client: MockClient((_) async =>
            http.Response(_respuesta(['Amén - Te Quiero.mp3']), 200)),
      );

      final canciones = await servicio.obtenerCanciones();

      expect(canciones.length, 1);
      expect(servicio.listaVieneDelWorker, isTrue);
      // El nombre del archivo viaja codificado dentro de la dirección.
      expect(canciones.first.url, contains('Am%C3%A9n'));
      expect(canciones.first.id, 'r2_Amén - Te Quiero.mp3');
    });

    test(
        'EL CASO QUE IMPORTA: sin señal aparece la biblioteca COMPLETA, '
        'no la foto vieja', () async {
      // Antes, quedarse sin internet te dejaba con la lista fija que
      // viaja dentro de la app. Esa lista no está mal --sus canciones
      // están en el servidor y suenan perfecto-- pero es una foto del
      // bucket del día en que se escribió: todo lo subido después no
      // figura. Los temas de Amén, por ejemplo.
      //
      // Así que veías una biblioteca a la que le faltaban canciones que
      // sí tenés, sin forma de saber cuáles. Ahora se recuerda la
      // última lista que sí vino del servidor, que sí está completa.
      final conSenial = DriveService(
        client: MockClient((_) async => http.Response(
            _respuesta(['Amén - Te Quiero.mp3', 'Amén - Libre.mp3']), 200)),
      );
      await conSenial.obtenerCanciones();
      // Ver la nota del test de más abajo: la lista se guarda sin
      // esperar.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Otra apertura de la app, ahora sin señal.
      final sinSenial = DriveService(
        client: MockClient((_) async => throw const SocketException('sin red')),
      );
      final canciones = await sinSenial.obtenerCanciones();

      expect(sinSenial.listaVieneDelWorker, isFalse,
          reason: 'hay que poder avisar que no se hablo con el servidor');
      expect(canciones.map((c) => c.id), [
        'r2_Amén - Te Quiero.mp3',
        'r2_Amén - Libre.mp3',
      ]);
    });

    test('la primera vez sin señal cae en la lista que trae la app', () async {
      // Nunca hubo internet, así que no hay nada guardado. Acá la lista
      // fija hace exactamente su trabajo: es eso o una pantalla vacía,
      // y esas canciones están en el servidor de verdad. Por eso NO se
      // borra aunque ya casi nunca se use.
      final servicio = DriveService(
        client: MockClient((_) async => throw const SocketException('sin red')),
      );

      final canciones = await servicio.obtenerCanciones();

      expect(canciones, isNotEmpty);
      expect(servicio.listaVieneDelWorker, isFalse);
    });

    test('una respuesta que no es 200 también cae en el respaldo', () async {
      final servicio = DriveService(
        client: MockClient((_) async => http.Response('', 503)),
      );

      expect(await servicio.obtenerCanciones(), isNotEmpty);
      expect(servicio.listaVieneDelWorker, isFalse);
    });

    test('no se le pregunta dos veces al servidor por lo mismo', () async {
      var consultas = 0;
      final servicio = DriveService(client: MockClient((_) async {
        consultas++;
        return http.Response(_respuesta(['Bohemian Rhapsody.mp3']), 200);
      }));

      await servicio.obtenerCanciones();
      await servicio.obtenerCanciones();
      expect(consultas, 1);

      // "Actualizar" sí tiene que volver a preguntar.
      await servicio.refrescarCanciones();
      expect(consultas, 2);
    });

    test('una lista guardada vieja se reemplaza por la nueva', () async {
      SharedPreferences.setMockInitialValues({
        'drive_lista_v1': ['Vieja.mp3'],
      });

      final servicio = DriveService(
        client: MockClient(
            (_) async => http.Response(_respuesta(['Nueva.mp3']), 200)),
      );
      await servicio.obtenerCanciones();
      // La lista se guarda sin esperar, a propósito: la biblioteca ya
      // está lista y guardarla no tiene que demorar que aparezca. Por
      // eso acá hay que darle un instante antes de mirar el disco.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('drive_lista_v1'), ['Nueva.mp3']);
    });

    test('el título y el artista salen del nombre del archivo', () async {
      final servicio = DriveService(
        client: MockClient((_) async => http.Response(
            _respuesta(['November Rain - Guns N\' Roses.mp3']), 200)),
      );

      final cancion = (await servicio.obtenerCanciones()).single;

      expect(cancion.title, 'November Rain');
      expect(cancion.artist, "Guns N' Roses");
    });
  });
}
