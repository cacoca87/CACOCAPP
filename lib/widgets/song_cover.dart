import 'package:flutter/material.dart';
import '../services/artwork_service.dart';
import '../services/id3_cover_service.dart';
import '../styles/app_theme.dart';

enum _CoverKind { bytes, url, none }

class _CoverResult {
  final _CoverKind kind;
  final dynamic data;
  const _CoverResult(this.kind, this.data);
}

class SongCover extends StatefulWidget {
  final String title;
  final String artist;
  final String url;
  final double size;
  final BorderRadius borderRadius;
  final bool showShadow;

  /// Carátula ya conocida de antemano (por ejemplo, la que devuelve
  /// la API de Jamendo junto con el resultado de búsqueda). Cuando
  /// viene con algo, se usa directo y NO se gasta una búsqueda de
  /// ID3/iTunes — esas son solo para cuando no tenemos ninguna pista
  /// de dónde sacar la carátula (como con tus canciones del Drive).
  final String coverUrlDirecto;

  const SongCover({
    super.key,
    required this.title,
    required this.artist,
    required this.url,
    this.size = 45,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.showShadow = false,
    this.coverUrlDirecto = '',
  });

  @override
  State<SongCover> createState() => _SongCoverState();
}

class _SongCoverState extends State<SongCover> {
  // Guardamos el Future una sola vez (no en build()) para que un
  // rebuild del padre (por ejemplo, un notifyListeners del provider)
  // no dispare un nuevo FutureBuilder "loading" -> "done" y el
  // consecuente parpadeo en listas largas.
  late Future<_CoverResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(covariant SongCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo recalculamos si esta instancia pasó a representar OTRA
    // canción (widget reciclado por una ListView con la misma key).
    if (oldWidget.url != widget.url ||
        oldWidget.title != widget.title ||
        oldWidget.artist != widget.artist ||
        oldWidget.coverUrlDirecto != widget.coverUrlDirecto) {
      _future = _resolve();
    }
  }

  Future<_CoverResult> _resolve() async {
    if (widget.coverUrlDirecto.isNotEmpty) {
      return _CoverResult(_CoverKind.url, widget.coverUrlDirecto);
    }

    if (widget.url.isNotEmpty) {
      final embedded =
          await Id3CoverService.instance.getEmbeddedCover(widget.url);
      if (embedded != null) return _CoverResult(_CoverKind.bytes, embedded);
    }

    final itunesUrl =
        await ArtworkService.instance.getCoverUrl(widget.title, widget.artist);
    if (itunesUrl != null) return _CoverResult(_CoverKind.url, itunesUrl);

    return const _CoverResult(_CoverKind.none, null);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CoverResult>(
      future: _future,
      builder: (context, snapshot) {
        final result = snapshot.data;

        if (snapshot.connectionState != ConnectionState.done) {
          return _placeholder(loading: true);
        }

        if (result == null || result.kind == _CoverKind.none) {
          return _placeholder();
        }

        // Las caratulas vienen a 600x600 o mas. Sin `cacheWidth`,
        // Flutter las decodifica a tamano completo en memoria aunque
        // se dibujen en un cuadradito de 44 px: eso es ~1,4 MB de RAM
        // por fila, y una biblioteca de cientos de canciones recorrida
        // de punta a punta hacia trabar el scroll en celulares de
        // gama media. Le pedimos que decodifique al tamano real de
        // pantalla (logico x densidad del dispositivo).
        //
        // Va SOLO el ancho, sin el alto. Cuando se dan los dos, Flutter
        // decodifica a esas medidas exactas y deja de respetar la
        // proporcion de la imagen: una tapa que no sea cuadrada (las hay
        // rectangulares, sobre todo las que vienen dentro del MP3) se
        // aplastaba para entrar en el cuadrado, y despues `BoxFit.cover`
        // ya no podia arreglarlo porque recibia la imagen deformada. Con
        // el ancho solo, el alto sale proporcional y el recorte lo hace
        // `cover`, que es su trabajo.
        final densidad = MediaQuery.devicePixelRatioOf(context);
        final ladoEnPixeles = (widget.size * densidad).round();

        Widget image;
        if (result.kind == _CoverKind.bytes) {
          image = Image.memory(
            result.data,
            width: widget.size,
            height: widget.size,
            cacheWidth: ladoEnPixeles,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          );
        } else {
          image = Image.network(
            result.data as String,
            width: widget.size,
            height: widget.size,
            cacheWidth: ladoEnPixeles,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          );
        }

        Widget cover =
            ClipRRect(borderRadius: widget.borderRadius, child: image);
        if (widget.showShadow) {
          cover = Container(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: cover,
          );
        }
        return cover;
      },
    );
  }

  Widget _placeholder({bool loading = false}) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Container(
        width: widget.size,
        height: widget.size,
        color: AppTheme.surfaceRaised,
        child: loading
            ? Padding(
                padding: EdgeInsets.all(widget.size * 0.28),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.amber,
                ),
              )
            : Icon(Icons.music_note_rounded,
                color: AppTheme.mutedInk, size: widget.size * 0.5),
      ),
    );
  }
}
