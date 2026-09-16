// Diagnóstico: ¿se puede sacar hoy el audio directo de un video de
// YouTube y REPRODUCIRLO? No alcanza con obtener la URL: hay que
// comprobar que el servidor la sirva de verdad. Se prueba con
// busquedas reales, como las que hace la app.
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> args) async {
  final yt = YoutubeExplode();
  final busquedas = args.isNotEmpty
      ? args
      : [
          'Aerosmith Hole In My Soul',
          'Guns N Roses November Rain',
          'Queen Bohemian Rhapsody',
          'Marc Anthony Flor Palida',
          'Led Zeppelin Kashmir',
          'Nirvana Smells Like Teen Spirit',
        ];

  var ok = 0;
  for (final texto in busquedas) {
    stdout.write('$texto -> ');
    try {
      final resultados = await yt.search.search(texto);
      if (resultados.isEmpty) {
        stdout.writeln('sin resultados');
        continue;
      }
      final video = resultados.first;
      final manifiesto = await yt.videos.streamsClient.getManifest(video.id);
      final mejor = manifiesto.audioOnly.withHighestBitrate();

      final cliente = HttpClient();
      final pedido = await cliente.getUrl(mejor.url);
      pedido.headers.set('Range', 'bytes=0-2047');
      final respuesta = await pedido.close();
      final codigo = respuesta.statusCode;
      await respuesta.drain<void>();
      cliente.close();

      if (codigo == 200 || codigo == 206) ok++;
      stdout.writeln('$codigo  (${video.title})');
    } catch (e) {
      stdout.writeln('FALLO: ${e.runtimeType}');
    }
  }
  stdout.writeln('');
  stdout.writeln('Funcionaron $ok de ${busquedas.length}');
  yt.close();
}
