import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../styles/app_theme.dart';

/// Comprueba, DESDE ESTE CELULAR, si YouTube deja bajar el audio de un
/// video completo.
///
/// Por qué existe: la misma prueba se hizo desde una computadora y dio
/// que no se puede -- YouTube entrega el primer pedazo del archivo y
/// rechaza el resto. Pero esa medición se hizo desde otra conexión y
/// otro aparato, y eso puede cambiar el resultado. Esta pantalla lo
/// resuelve sin suponer nada: corre la prueba acá, con esta conexión.
///
/// Lo que decide es el SEGUNDO pedazo. El primero YouTube lo entrega
/// siempre, aunque todo lo demás esté bloqueado: una prueba que solo
/// pida el principio del archivo da bien y engaña.
class DiagnosticoYoutubeScreen extends StatefulWidget {
  const DiagnosticoYoutubeScreen({super.key});

  @override
  State<DiagnosticoYoutubeScreen> createState() =>
      _DiagnosticoYoutubeScreenState();
}

class _DiagnosticoYoutubeScreenState extends State<DiagnosticoYoutubeScreen> {
  static const int _tamanoTrozo = 1048576; // 1 MB

  final List<String> _lineas = [];
  bool _corriendo = false;
  bool? _sePuede;

  void _anotar(String texto) {
    if (!mounted) return;
    setState(() => _lineas.add(texto));
  }

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
    } catch (e) {
      _anotar('   (error de red: ${e.runtimeType})');
      return (0, 0);
    } finally {
      cliente.close();
    }
  }

  Future<void> _correr() async {
    setState(() {
      _lineas.clear();
      _corriendo = true;
      _sePuede = null;
    });

    final yt = YoutubeExplode();
    try {
      _anotar('Buscando una canción para probar...');
      final resultados = await yt.search.search('Guns N Roses November Rain');
      if (resultados.isEmpty) {
        _anotar('No hubo resultados. ¿Hay internet?');
        return;
      }
      final video = resultados.first;
      _anotar('Video: ${video.title}');

      _anotar('Pidiendo la dirección del audio...');
      final manifiesto = await yt.videos.streamsClient.getManifest(video.id);
      final soloAudio = manifiesto.audioOnly;
      if (soloAudio.isEmpty) {
        _anotar('Este video no tiene pista de audio suelta.');
        if (mounted) setState(() => _sePuede = false);
        return;
      }
      final pista = soloAudio.withHighestBitrate();
      final total = pista.size.totalBytes;
      _anotar('Dirección conseguida ✓  (el archivo pesa $total bytes)');

      _anotar('');
      _anotar('Pidiendo el primer pedazo (este siempre pasa)...');
      final uno = await _pedirTrozo(pista.url, 0, _tamanoTrozo - 1);
      _anotar('   respuesta ${uno.$1} · ${uno.$2} bytes');

      _anotar('');
      _anotar('Pidiendo el SEGUNDO pedazo (este es el que decide)...');
      final dos = await _pedirTrozo(
          pista.url, _tamanoTrozo, (_tamanoTrozo * 2 - 1).clamp(0, total - 1));
      _anotar('   respuesta ${dos.$1} · ${dos.$2} bytes');

      final anduvo = (dos.$1 == 200 || dos.$1 == 206) && dos.$2 > 0;
      if (mounted) setState(() => _sePuede = anduvo);
      _anotar('');
      _anotar(anduvo
          ? 'El segundo pedazo LLEGÓ. Desde este celular sí se puede bajar '
              'la canción entera, y entonces sí se puede reproducir con la '
              'pantalla bloqueada. Avisale a quien programó la app.'
          : 'El segundo pedazo fue RECHAZADO. YouTube entrega el principio '
              'del archivo y corta, así que la canción nunca se completa. '
              'No es un problema de la app ni de la conexión.');
    } catch (e) {
      _anotar('Se cortó: $e');
      if (mounted) setState(() => _sePuede = false);
    } finally {
      yt.close();
      if (mounted) setState(() => _corriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultado = _sePuede;
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        title: Text('Prueba de YouTube',
            style: AppTheme.subheading.copyWith(fontSize: 16)),
        actions: [
          if (_lineas.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: AppTheme.paper),
              tooltip: 'Copiar el resultado',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _lineas.join('\n')));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Resultado copiado')),
                );
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comprueba si YouTube deja bajar una canción completa desde '
              'ESTE celular. Lo que decide es el segundo pedazo del '
              'archivo: el primero YouTube lo entrega siempre, aunque el '
              'resto esté bloqueado.',
              style: AppTheme.small.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: AppTheme.primaryButton,
                onPressed: _corriendo ? null : _correr,
                icon: _corriendo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.ink),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(_corriendo ? 'Probando...' : 'Hacer la prueba'),
              ),
            ),
            if (resultado != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (resultado ? AppTheme.primary : AppTheme.danger)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: resultado ? AppTheme.primary : AppTheme.danger),
                ),
                child: Text(
                  resultado
                      ? 'SÍ se puede desde este celular'
                      : 'NO se puede: YouTube corta después del primer pedazo',
                  style: AppTheme.body.copyWith(
                    color: resultado ? AppTheme.primary : AppTheme.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _lineas.isEmpty
                        ? 'Todavía no se hizo la prueba.'
                        : _lineas.join('\n'),
                    style: AppTheme.small.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppTheme.paper,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
