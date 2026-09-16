// ¿Se puede hoy sacar el audio de un video de YouTube y reproducirlo
// dentro de la app?
//
// Se corre así, desde la carpeta del proyecto:
//
//     dart run tool/probar_audio_youtube.dart
//
// POR QUÉ EXISTE ESTE ARCHIVO
//
// Es la pregunta que decide si la Búsqueda Online puede sonar con la
// pantalla bloqueada. El reproductor embebido de YouTube es una vista
// web y Android la congela al apagar la pantalla; la única salida sería
// sacar el audio suelto y mandarlo al motor de audio de la app, que sí
// corre como servicio del sistema.
//
// LA TRAMPA, Y POR QUÉ ESTA PRUEBA MIDE LO QUE MIDE
//
// Una prueba que solo pide los primeros kilobytes DA BIEN aunque todo
// esté roto. YouTube entrega el primer pedazo del archivo sin chistar
// y rechaza todo lo demás. Una prueba así se hizo, dio "6 de 6", y era
// falsa: la app fallaba igual.
//
// Por eso acá se pide el SEGUNDO trozo, que es el que decide. Si el
// segundo trozo llega, se puede reproducir; si no, no. Todo lo demás
// que se imprime es contexto para entender por qué.
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const int _tamanoTrozo = 1048576; // 1 MB

Future<(int codigo, int bytes)> _pedirTrozo(
    Uri url, int desde, int hasta) async {
  final cliente = HttpClient();
  try {
    final pedido = await cliente.getUrl(url);
    pedido.headers.set('Range', 'bytes=$desde-$hasta');
    final respuesta = await pedido.close();
    var bytes = 0;
    await for (final trozo in respuesta) {
      bytes += trozo.length;
    }
    return (respuesta.statusCode, bytes);
  } catch (_) {
    return (0, 0);
  } finally {
    cliente.close();
  }
}

Future<void> main(List<String> args) async {
  final yt = YoutubeExplode();
  final busquedas = args.isNotEmpty
      ? args
      : [
          'Los Cafres Aire',
          'Aerosmith Hole In My Soul',
          'Queen Bohemian Rhapsody'
        ];

  var completos = 0;
  for (final texto in busquedas) {
    stdout.writeln('=== $texto');
    try {
      final resultados = await yt.search.search(texto);
      if (resultados.isEmpty) {
        stdout.writeln('  sin resultados');
        continue;
      }
      final video = resultados.first;
      final manifiesto = await yt.videos.streamsClient.getManifest(video.id);
      final soloAudio = manifiesto.audioOnly;
      if (soloAudio.isEmpty) {
        stdout.writeln('  el video no tiene pista de solo audio');
        continue;
      }

      final enMp4 = soloAudio.where((s) => s.codec.mimeType.contains('mp4'));
      final pista = enMp4.isNotEmpty
          ? enMp4.reduce((a, b) =>
              a.bitrate.bitsPerSecond >= b.bitrate.bitsPerSecond ? a : b)
          : soloAudio.withHighestBitrate();
      final total = pista.size.totalBytes;
      stdout.writeln('  ${video.title}');
      stdout.writeln('  la URL se consiguió: sí  ($total bytes en total)');

      final primero = await _pedirTrozo(pista.url, 0, _tamanoTrozo - 1);
      stdout.writeln('  trozo 1 (el que siempre pasa): '
          '${primero.$1}  ${primero.$2} bytes');

      if (total <= _tamanoTrozo) {
        stdout.writeln('  (el archivo entra en un solo trozo, no decide nada)');
        continue;
      }

      final segundo = await _pedirTrozo(
          pista.url, _tamanoTrozo, (_tamanoTrozo * 2 - 1).clamp(0, total - 1));
      final anduvo = segundo.$1 == 200 || segundo.$1 == 206;
      stdout.writeln('  trozo 2 (EL QUE DECIDE):      '
          '${segundo.$1}  ${segundo.$2} bytes  ${anduvo ? "OK" : "RECHAZADO"}');
      if (anduvo) completos++;
    } catch (e) {
      stdout.writeln('  falló: $e');
    }
  }

  stdout.writeln('');
  if (completos == 0) {
    stdout.writeln('RESULTADO: no se puede. YouTube entrega el primer pedazo');
    stdout.writeln('y rechaza el resto, así que la canción nunca se completa.');
    stdout
        .writeln('La Búsqueda Online tiene que seguir con el video embebido,');
    stdout
        .writeln('que se calla al bloquear la pantalla. Para escuchar con la');
    stdout.writeln('pantalla apagada están la biblioteca propia y Descubrir.');
  } else {
    stdout
        .writeln('RESULTADO: $completos de ${busquedas.length} entregaron el');
    stdout
        .writeln('segundo trozo. Si esto pasa de forma consistente, volver a');
    stdout.writeln('intentar el audio suelto tiene sentido.');
  }
  yt.close();
}
