import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/ruta_de_archivo.dart';

void main() {
  group('rutaDeArchivoDe', () {
    test('EL CASO REAL: una canción descargada viene como file://', () {
      // Así guarda la app la dirección de una canción descargada, y así
      // le llega al servicio que lee los tags del MP3.
      //
      // Se le pasaba tal cual a `File`, que no falla con un error:
      // arma un archivo cuyo nombre es, literalmente,
      // "file:///data/...". Ese archivo no existe nunca, así que la
      // comprobación decía tranquilamente "no está" y todo seguía como
      // si la canción no tuviera nada adentro.
      //
      // Lo que rompía: las canciones DESCARGADAS se quedaban sin su
      // carátula en la pantalla de bloqueo y la app salía a buscarla a
      // internet, que es lo contrario de para qué se descarga una
      // canción. Y su letra incrustada tampoco se leía nunca.
      //
      // Se comprueba por partes y no contra un texto exacto a propósito:
      // la barra que separa carpetas la pone el sistema donde corre
      // esto, y no es la misma en el celular (/) que en la computadora
      // donde se corren los tests (\). Lo que importa es que el
      // "file://" ya no esté y que el nombre del archivo quede intacto.
      final ruta = rutaDeArchivoDe(
          'file:///data/user/0/com.caco.musicapp/descargas/x.mp3');

      expect(ruta, isNotNull);
      expect(ruta, isNot(startsWith('file:')));
      expect(ruta, endsWith('x.mp3'));
      expect(ruta, contains('descargas'));
    });

    test('una dirección de internet NO es un archivo', () {
      expect(rutaDeArchivoDe('https://ejemplo.test/Roxanne.mp3'), isNull);
      expect(rutaDeArchivoDe('http://ejemplo.test/Roxanne.mp3'), isNull);
    });

    test('una ruta pelada se deja como está', () {
      expect(rutaDeArchivoDe('/data/descargas/x.mp3'), '/data/descargas/x.mp3');
    });

    test('vacío no es nada', () {
      expect(rutaDeArchivoDe(''), isNull);
    });

    test('los nombres con espacios y acentos vuelven bien', () {
      // Los nombres de archivo de esta biblioteca están llenos de los
      // dos: "Amén - Te Quiero.mp3", "November Rain - Guns N' Roses.mp3".
      // En una dirección viajan codificados, y hay que devolverlos a su
      // forma normal o el archivo no se encuentra.
      expect(
        rutaDeArchivoDe('file:///datos/Am%C3%A9n%20-%20Te%20Quiero.mp3'),
        endsWith('Amén - Te Quiero.mp3'),
      );
    });
  });

  group('esUnArchivoQueYaNoEsta', () {
    // Lo que decide si el reproductor reintenta o no. Cuando falla,
    // la app supone que se cortó internet: reintenta ocho veces
    // esperando cada vez más y termina diciendo "revisá tu señal".
    // Con un archivo del propio celular eso está mal dos veces:
    // reintentar no puede funcionar --no va a aparecer solo-- y el
    // mensaje es falso.
    bool nadaExiste(String _) => false;
    bool todoExiste(String _) => true;

    test('un archivo del celular que se borró: SÍ', () {
      // Pasa de verdad y es fácil: borrás un MP3 con el administrador
      // de archivos y esa canción seguía en una playlist.
      expect(esUnArchivoQueYaNoEsta('file:///Music/a.mp3', nadaExiste), isTrue);
    });

    test('un archivo del celular que sigue ahí: no', () {
      expect(esUnArchivoQueYaNoEsta('file:///Music/a.mp3', todoExiste), isFalse);
    });

    test('algo de internet: NUNCA, aunque no responda', () {
      // Ahí sí puede ser la conexión, y reintentar es lo correcto.
      expect(esUnArchivoQueYaNoEsta('https://r2.test/a.mp3', nadaExiste),
          isFalse);
      expect(
          esUnArchivoQueYaNoEsta('http://r2.test/a.mp3', nadaExiste), isFalse);
    });

    test('una dirección vacía no rompe nada', () {
      expect(esUnArchivoQueYaNoEsta('', nadaExiste), isFalse);
    });

    test('una ruta pelada también cuenta como archivo', () {
      expect(
          esUnArchivoQueYaNoEsta('/storage/Music/a.mp3', nadaExiste), isTrue);
    });
  });
}
