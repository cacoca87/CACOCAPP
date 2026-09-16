import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/lyrics_service.dart';
import '../styles/app_theme.dart';

/// Letra que se va resaltando al ritmo de lo que suena, con la línea
/// actual en grande y el resto atenuado.
///
/// Vive acá y no dentro de una pantalla porque hay DOS lugares que la
/// necesitan y tienen que comportarse igual: la pantalla de Letra de la
/// biblioteca y el panel de abajo del video de YouTube. Lo único que
/// cambia entre las dos es de dónde sale la posición: del motor de
/// audio en un caso, del reproductor de YouTube en el otro. Por eso
/// entra como un `Stream<Duration>` y no atada a ninguno de los dos.
class LetraSincronizada extends StatefulWidget {
  final List<LineaLetra> lineas;

  /// De dónde sale el "por dónde va" la reproducción.
  final Stream<Duration> posicion;

  /// Qué hacer cuando se toca una línea. Si es `null`, las líneas no
  /// responden al toque (por ejemplo, cuando saltar no es confiable).
  final ValueChanged<Duration>? onTocarLinea;

  /// Con qué nombre se guarda el ajuste de desfase de ESTA canción. Si
  /// viene `null`, el ajuste funciona igual pero no se recuerda.
  final String? claveDeAjuste;

  final EdgeInsets padding;

  const LetraSincronizada({
    super.key,
    required this.lineas,
    required this.posicion,
    this.onTocarLinea,
    this.claveDeAjuste,
    this.padding = const EdgeInsets.symmetric(vertical: 140, horizontal: 28),
  });

  @override
  State<LetraSincronizada> createState() => _LetraSincronizadaState();
}

class _LetraSincronizadaState extends State<LetraSincronizada> {
  final ScrollController _scroll = ScrollController();
  int _ultimaLineaResaltada = -1;

  /// Alto aproximado de cada renglón, para calcular a dónde desplazarse.
  static const double _alturaPorLinea = 56.0;

  /// Cuándo fue la última vez que la persona movió la letra con el
  /// dedo, y cuánto se espera antes de volver a seguirla sola. Sin esta
  /// pausa no se podía leer más adelante: al cambiar de línea, la
  /// pantalla te devolvía de un tirón al renglón que sonaba.
  DateTime? _ultimoArrastre;
  static const Duration _pausaTrasArrastre = Duration(seconds: 6);

  /// Cuánto se corren los tiempos de la letra respecto de la música.
  ///
  /// Hace falta porque las letras con tiempos vienen de una base
  /// pública y están hechas sobre UNA grabación: si tu archivo es otra
  /// edición, o tiene una intro más larga, los tiempos quedan corridos
  /// y la letra va adelantada o atrasada toda la canción. Probando la
  /// app fue justamente uno de los reclamos.
  ///
  /// Positivo = la letra iba adelantada y se retrasa.
  Duration _ajuste = Duration.zero;
  static const Duration _paso = Duration(milliseconds: 500);
  static const Duration _ajusteMaximo = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _cargarAjuste();
  }

  @override
  void didUpdateWidget(covariant LetraSincronizada oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Otra canción: su ajuste es el suyo, no el de la anterior.
    if (oldWidget.claveDeAjuste != widget.claveDeAjuste) {
      _ajuste = Duration.zero;
      _ultimaLineaResaltada = -1;
      _cargarAjuste();
    }
  }

  String? get _claveGuardada {
    final clave = widget.claveDeAjuste;
    if (clave == null || clave.isEmpty) return null;
    return 'letra_ajuste_v1_$clave';
  }

  Future<void> _cargarAjuste() async {
    final clave = _claveGuardada;
    if (clave == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(clave);
      if (ms == null || !mounted) return;
      setState(() => _ajuste = Duration(milliseconds: ms));
    } catch (_) {
      // Sin ajuste guardado se muestra igual, sin corrimiento.
    }
  }

  Future<void> _guardarAjuste() async {
    final clave = _claveGuardada;
    if (clave == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_ajuste == Duration.zero) {
        await prefs.remove(clave);
      } else {
        await prefs.setInt(clave, _ajuste.inMilliseconds);
      }
    } catch (_) {}
  }

  void _corregir(Duration cuanto) {
    HapticFeedback.selectionClick();
    final nuevo = _ajuste + cuanto;
    if (nuevo > _ajusteMaximo || nuevo < -_ajusteMaximo) return;
    setState(() {
      _ajuste = nuevo;
      // Para que el próximo cambio de línea vuelva a centrar la vista.
      _ultimaLineaResaltada = -1;
    });
    _guardarAjuste();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int _indiceDe(Duration posicion) {
    final efectiva = posicion - _ajuste;
    var indice = -1;
    for (var i = 0; i < widget.lineas.length; i++) {
      if (widget.lineas[i].tiempo <= efectiva) {
        indice = i;
      } else {
        break;
      }
    }
    return indice;
  }

  void _irALinea(int indice) {
    if (indice < 0 || indice == _ultimaLineaResaltada) return;
    _ultimaLineaResaltada = indice;
    if (!_scroll.hasClients) return;
    final arrastre = _ultimoArrastre;
    if (arrastre != null &&
        DateTime.now().difference(arrastre) < _pausaTrasArrastre) {
      return;
    }
    final destino = (indice * _alturaPorLinea) - 180;
    _scroll.animateTo(
      destino.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<Duration>(
          stream: widget.posicion,
          builder: (context, snapshot) {
            final indiceActual = _indiceDe(snapshot.data ?? Duration.zero);

            WidgetsBinding.instance
                .addPostFrameCallback((_) => _irALinea(indiceActual));

            return NotificationListener<ScrollNotification>(
              onNotification: (aviso) {
                if (aviso is ScrollStartNotification &&
                    aviso.dragDetails != null) {
                  _ultimoArrastre = DateTime.now();
                }
                return false;
              },
              child: ListView.builder(
                controller: _scroll,
                padding: widget.padding,
                itemCount: widget.lineas.length,
                itemBuilder: (context, index) {
                  final activa = index == indiceActual;
                  final linea = widget.lineas[index];
                  return GestureDetector(
                    // `opaque` para que se pueda tocar todo el renglón,
                    // no solo las letras: en las líneas cortas había que
                    // apuntarle justo al texto.
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onTocarLinea == null
                        ? null
                        : () => widget.onTocarLinea!(linea.tiempo),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: activa ? AppTheme.paper : AppTheme.faintInk,
                          fontSize: activa ? 22 : 18,
                          fontWeight:
                              activa ? FontWeight.bold : FontWeight.normal,
                          height: 1.4,
                        ),
                        child: Text(linea.texto),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Center(
              child: _ControlDeDesfase(ajuste: _ajuste, onCorregir: _corregir)),
        ),
      ],
    );
  }
}

/// Los dos botones para correr la letra cuando va adelantada o
/// atrasada, con el desfase actual en el medio.
class _ControlDeDesfase extends StatelessWidget {
  final Duration ajuste;
  final ValueChanged<Duration> onCorregir;

  const _ControlDeDesfase({required this.ajuste, required this.onCorregir});

  String get _texto {
    if (ajuste == Duration.zero) return 'Ajustar';
    final segundos = ajuste.inMilliseconds / 1000;
    final signo = segundos > 0 ? '+' : '';
    return '$signo${segundos.toStringAsFixed(1)} s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.fast_rewind_rounded,
                color: AppTheme.mutedInk, size: 20),
            tooltip: 'La letra va atrasada: adelantarla medio segundo',
            visualDensity: VisualDensity.compact,
            onPressed: () => onCorregir(-_LetraSincronizadaState._paso),
          ),
          Text(
            _texto,
            style: AppTheme.small.copyWith(
              color:
                  ajuste == Duration.zero ? AppTheme.faintInk : AppTheme.amber,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fast_forward_rounded,
                color: AppTheme.mutedInk, size: 20),
            tooltip: 'La letra va adelantada: retrasarla medio segundo',
            visualDensity: VisualDensity.compact,
            onPressed: () => onCorregir(_LetraSincronizadaState._paso),
          ),
        ],
      ),
    );
  }
}
