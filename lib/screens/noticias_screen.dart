import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/noticia.dart';
import '../services/noticias_service.dart';
import '../styles/app_theme.dart';
import '../widgets/estado_vacio.dart';

/// Noticias por categoría: negocios internacionales, comercio global,
/// logística, cadena de suministro, contratos, tecnología y música.
///
/// Las noticias se abren en el navegador del celular y no adentro de la
/// app: son sitios de terceros con sus propios anuncios y ventanas de
/// consentimiento, y meterlos en un WebView propio daría una experiencia
/// peor que la del navegador, que ya tiene lector, zoom y traductor.
class NoticiasScreen extends StatefulWidget {
  final VoidCallback? onVolver;
  const NoticiasScreen({super.key, this.onVolver});

  @override
  State<NoticiasScreen> createState() => _NoticiasScreenState();
}

class _NoticiasScreenState extends State<NoticiasScreen> {
  CategoriaNoticias _categoria = NoticiasService.categorias.first;
  List<Noticia> _noticias = const [];
  bool _cargando = true;
  ErrorNoticias? _error;

  /// Se incrementa con cada pedido. Igual que en las búsquedas: si
  /// cambiás de categoría mientras una carga lenta sigue en la red, la
  /// respuesta vieja no tiene que pisar a la nueva.
  int _generacion = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool forzar = false}) async {
    final generacion = ++_generacion;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final noticias =
          await NoticiasService.instance.obtener(_categoria, forzar: forzar);
      if (!mounted || generacion != _generacion) return;
      setState(() {
        _noticias = noticias;
        _cargando = false;
      });
    } on ErrorNoticias catch (e) {
      if (!mounted || generacion != _generacion) return;
      setState(() {
        _error = e;
        _noticias = const [];
        _cargando = false;
      });
    }
  }

  void _cambiarCategoria(CategoriaNoticias c) {
    if (c.nombre == _categoria.nombre) return;
    setState(() => _categoria = c);
    _cargar();
  }

  Future<void> _abrir(Noticia noticia) async {
    HapticFeedback.selectionClick();
    final uri = Uri.tryParse(noticia.enlace);
    var abrio = false;
    try {
      // `launchUrl` no solo devuelve `false` cuando no puede: también
      // puede lanzar excepción (por ejemplo si el sistema no tiene
      // ningún navegador). Sin este `try`, eso quedaría como un error
      // sin manejar en medio de un toque del usuario.
      if (uri != null) {
        abrio = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      abrio = false;
    }
    if (!abrio && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la noticia.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        title:
            Text('Noticias', style: AppTheme.subheading.copyWith(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.paper),
          tooltip: 'Volver',
          onPressed: widget.onVolver,
        ),
      ),
      body: Column(
        children: [
          // El alto crece con la escala de texto del sistema: con la
          // letra grande, un alto fijo dejaba los chips cortados. Mismo
          // motivo que en `mini_player.dart`.
          SizedBox(
            height: 44 *
                MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: NoticiasService.categorias.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = NoticiasService.categorias[i];
                final activa = c.nombre == _categoria.nombre;
                return ChoiceChip(
                  label: Text(c.nombre),
                  selected: activa,
                  onSelected: (_) => _cambiarCategoria(c),
                  backgroundColor: AppTheme.surface,
                  selectedColor: AppTheme.amber,
                  labelStyle: AppTheme.body.copyWith(
                    fontSize: 13,
                    color: activa ? AppTheme.ink : AppTheme.mutedInk,
                    fontWeight: activa ? FontWeight.w700 : FontWeight.w400,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: activa ? AppTheme.amber : AppTheme.hairline,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _contenido()),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.amber),
      );
    }

    final error = _error;
    if (error != null) {
      return EstadoVacio(
        icono: error.sinConexion
            ? Icons.wifi_off_rounded
            : Icons.newspaper_outlined,
        mensaje: error.mensaje,
        accion: ElevatedButton.icon(
          style: AppTheme.primaryButton,
          onPressed: () => _cargar(forzar: true),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reintentar'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(forzar: true),
      color: AppTheme.amber,
      backgroundColor: AppTheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _noticias.length,
        itemBuilder: (context, i) => _TarjetaNoticia(
          noticia: _noticias[i],
          onTap: () => _abrir(_noticias[i]),
        ),
      ),
    );
  }
}

class _TarjetaNoticia extends StatelessWidget {
  final Noticia noticia;
  final VoidCallback onTap;

  const _TarjetaNoticia({required this.noticia, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final antiguedad = noticia.antiguedad;
    final pie = [
      if (noticia.fuente.isNotEmpty) noticia.fuente,
      if (antiguedad.isNotEmpty) antiguedad,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      noticia.titulo,
                      style: AppTheme.body.copyWith(
                        color: AppTheme.paper,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (pie.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(pie, style: AppTheme.small.copyWith(fontSize: 11)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new_rounded,
                  color: AppTheme.mutedInk, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
