import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/filtro_musica_local.dart';

/// Atajo: ¿este archivo entraría a la biblioteca?
bool entra(String ruta, {int segundos = 200}) =>
    porQueNoEsMusica(ruta: ruta, duracionSegundos: segundos) == null;

void main() {
  group('lo que NO tiene que sonar nunca en la biblioteca', () {
    test('una nota de voz de WhatsApp', () {
      // Es EL caso que motivó todo esto: se acaba una canción y lo que
      // sigue es una conversación tuya por el parlante, con el celular
      // en el bolsillo.
      expect(
        entra('/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/'
            'Media/WhatsApp Voice Notes/202401/PTT-20240115-WA0001.opus'),
        isFalse,
      );
    });

    test('un audio de WhatsApp aunque lo hayan movido a Música', () {
      // El nombre lleva la marca de WhatsApp adentro, así que se
      // reconoce igual fuera de su carpeta.
      expect(
          entra('/storage/emulated/0/Music/AUD-20240115-WA0001.mp3'), isFalse);
    });

    test('una grabación de la grabadora del celular', () {
      expect(
        entra('/storage/emulated/0/Recordings/Grabacion 001.m4a'),
        isFalse,
      );
      expect(
        entra('/storage/emulated/0/Sounds/Grabadora/nota.mp3'),
        isFalse,
      );
    });

    test('una grabación de llamada', () {
      expect(
        entra('/storage/emulated/0/Call Recording/2024-01-15 mama.mp3'),
        isFalse,
      );
    });

    test('un audio de Telegram', () {
      expect(
        entra('/storage/emulated/0/Android/media/org.telegram.messenger/'
            'Telegram/Telegram Audio/audio.ogg'),
        isFalse,
      );
    });

    test('un tono de llamada o un sonido de notificación', () {
      expect(entra('/system/media/audio/ringtones/Ring.ogg'), isFalse);
      expect(entra('/system/media/audio/notifications/Tink.ogg'), isFalse);
      expect(entra('/system/media/audio/alarms/Oxygen.ogg'), isFalse);
      expect(entra('/system/media/audio/ui/camera_click.ogg'), isFalse);
    });

    test('lo que Android ya marcó como que no es música', () {
      // Esto atrapa lo que se guardó en un lugar raro: si el sistema ya
      // sabe que es un tono o una grabación, alcanza con hacerle caso.
      expect(
        porQueNoEsMusica(
            ruta: '/Music/cualquiera.mp3',
            duracionSegundos: 200,
            esTimbre: true),
        MotivoDeDescarte.loMarcoAndroid,
      );
      expect(
        porQueNoEsMusica(
            ruta: '/Music/cualquiera.mp3',
            duracionSegundos: 200,
            esGrabacion: true),
        MotivoDeDescarte.loMarcoAndroid,
      );
      expect(
        porQueNoEsMusica(
            ruta: '/Music/cualquiera.mp3',
            duracionSegundos: 200,
            esPodcast: true),
        MotivoDeDescarte.loMarcoAndroid,
      );
    });

    test('un audio cortito, aunque esté en la carpeta de música', () {
      // Un "ahí voy" de cinco segundos, o un sonido suelto.
      expect(entra('/storage/emulated/0/Music/algo.mp3', segundos: 6), isFalse);
    });

    test('un formato que no se usa para música', () {
      // `.opus` es lo de las notas de voz; `.amr` y `.3gp`, grabaciones
      // viejas. Va por lista de lo PERMITIDO, así que un formato nuevo
      // de notas de voz queda afuera solo.
      expect(entra('/storage/emulated/0/Music/algo.opus'), isFalse);
      expect(entra('/storage/emulated/0/Music/algo.amr'), isFalse);
      expect(entra('/storage/emulated/0/Music/algo.3gp'), isFalse);
    });
  });

  group('lo que SÍ es música y tiene que entrar', () {
    test('una canción normal en la carpeta de música', () {
      expect(entra('/storage/emulated/0/Music/Queen - Bohemian Rhapsody.mp3'),
          isTrue);
    });

    test('una canción en Descargas', () {
      // Bajar un MP3 del navegador es de las formas más comunes de
      // tener música en el celular.
      expect(
          entra('/storage/emulated/0/Download/Amén - Te Quiero.mp3'), isTrue);
    });

    test('los otros formatos de música', () {
      for (final ext in ['m4a', 'flac', 'wav', 'aac', 'ogg', 'wma']) {
        expect(entra('/storage/emulated/0/Music/tema.$ext'), isTrue,
            reason: '$ext tendría que entrar');
      }
    });

    test('no importa si la ruta está en mayúsculas', () {
      expect(entra('/Storage/Emulated/0/MUSIC/Tema.MP3'), isTrue);
      expect(entra('/Storage/Emulated/0/WhatsApp/AUDIO.MP3'), isFalse);
    });

    test('una canción con acentos y espacios en el nombre', () {
      expect(
        entra('/storage/emulated/0/Music/Amén - Sé Que Tú No Estás Solo.mp3'),
        isTrue,
      );
    });

    test('justo en el límite de duración', () {
      expect(entra('/Music/x.mp3', segundos: 44), isFalse);
      expect(entra('/Music/x.mp3', segundos: 45), isTrue);
    });
  });

  group('el motivo se informa, para poder contarlos', () {
    test('cada regla dice cuál fue', () {
      expect(
        porQueNoEsMusica(ruta: '/WhatsApp/a.mp3', duracionSegundos: 200),
        MotivoDeDescarte.carpeta,
      );
      expect(
        porQueNoEsMusica(ruta: '/Music/a.opus', duracionSegundos: 200),
        MotivoDeDescarte.formato,
      );
      expect(
        porQueNoEsMusica(ruta: '/Music/a.mp3', duracionSegundos: 3),
        MotivoDeDescarte.muyCorto,
      );
      expect(
        porQueNoEsMusica(ruta: '/Music/a.mp3', duracionSegundos: 200),
        isNull,
      );
    });
  });
}
