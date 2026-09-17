import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../styles/app_theme.dart';
import '../utils/carrera_logica.dart';
import '../widgets/boton_volver.dart';
import '../widgets/controles_juego.dart';
import '../widgets/tablero_juego.dart';

/// Carrera de autos del "brick game" clásico. La lógica vive en
/// `utils/carrera_logica.dart` y está cubierta por tests; acá solo se
/// dibuja y se recogen los toques.
///
/// La música sigue sonando mientras jugás, igual que en Bloques.
class CarreraScreen extends StatefulWidget {
  final VoidCallback? onVolver;
  const CarreraScreen({super.key, this.onVolver});

  @override
  State<CarreraScreen> createState() => _CarreraScreenState();
}

class _CarreraScreenState extends State<CarreraScreen>
    with WidgetsBindingObserver {
  static const _claveRecord = 'carrera_record_v1';

  /// Índices de color del tablero: tu auto en ámbar, los rivales en rojo
  /// vino. Se corresponden con `TableroJuego.colores`.
  static const int _colorJugador = 1;
  static const int _colorRival = 3;

  final JuegoCarrera _juego = JuegoCarrera();
  Timer? _reloj;
  int _record = 0;
  bool _enPausa = false;
  // Se guarda al terminar, ANTES de actualizar `_record`: si se comparara
  // después, un puntaje igual al récord anterior también diría "nuevo".
  bool _fueRecord = false;
  int _nivelDelReloj = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarRecord();
    _programarReloj();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_enPausa) {
      setState(() => _enPausa = true);
    }
  }

  Future<void> _cargarRecord() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _record = prefs.getInt(_claveRecord) ?? 0);
    } catch (_) {}
  }

  Future<void> _guardarRecord(int puntaje) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Se compara contra lo GUARDADO, no contra lo que hay en memoria.
      //
      // El récord se lee del disco al abrir el juego, y esa lectura
      // tarda. Si perdías antes de que terminara --en estos juegos se
      // puede perder en dos segundos-- `_record` todavía valía 0, el
      // puntaje nuevo parecía récord, y se escribía encima del récord
      // de verdad. O sea que una partida mala te borraba la mejor.
      final guardado = prefs.getInt(_claveRecord) ?? 0;
      if (puntaje <= guardado) {
        // Lo que había era mejor: se deja, y se corrige lo que muestra
        // la pantalla.
        if (mounted && guardado != _record) {
          setState(() => _record = guardado);
        }
        return;
      }
      await prefs.setInt(_claveRecord, puntaje);
    } catch (_) {}
  }

  void _programarReloj() {
    _reloj?.cancel();
    _nivelDelReloj = _juego.nivel;
    _reloj = Timer.periodic(_juego.intervalo, (_) => _tic());
  }

  void _tic() {
    if (_enPausa || _juego.terminado) return;
    setState(_juego.avanzar);
    _revisarFinYVelocidad();
  }

  void _revisarFinYVelocidad() {
    if (_juego.terminado) {
      _reloj?.cancel();
      _fueRecord = _juego.puntaje > _record;
      if (_fueRecord) {
        setState(() => _record = _juego.puntaje);
        _guardarRecord(_juego.puntaje);
      }
      return;
    }
    if (_juego.nivel != _nivelDelReloj) _programarReloj();
  }

  void _accion(void Function() f) {
    if (_enPausa || _juego.terminado) return;
    setState(f);
    _revisarFinYVelocidad();
  }

  /// Cuánto hay que arrastrar para cambiar de carril. Lo suficiente
  /// como para que un roce no mueva el auto sin querer.
  static const double _pixelesPorCarril = 42;
  double _arrastreAcumulado = 0;

  void _arrastrar(DragUpdateDetails detalle) {
    if (_enPausa || _juego.terminado) return;
    _arrastreAcumulado += detalle.delta.dx;
    while (_arrastreAcumulado.abs() >= _pixelesPorCarril) {
      if (_arrastreAcumulado > 0) {
        _arrastreAcumulado -= _pixelesPorCarril;
        _accion(_juego.moverDerecha);
      } else {
        _arrastreAcumulado += _pixelesPorCarril;
        _accion(_juego.moverIzquierda);
      }
      if (_juego.terminado) break;
    }
  }

  void _reiniciar() {
    setState(() {
      _juego.reiniciar();
      _enPausa = false;
    });
    _programarReloj();
  }

  /// La pista tal como hay que dibujarla. La arma la lógica, que es
  /// quien sabe la forma de los autos.
  List<List<int>> get _vista => _juego.vista(
        colorJugador: _colorJugador,
        colorRival: _colorRival,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        title:
            Text('Carrera', style: AppTheme.subheading.copyWith(fontSize: 18)),
        leading: BotonVolver(onVolver: widget.onVolver),
        actions: [
          IconButton(
            icon: Icon(
              _enPausa ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: AppTheme.paper,
            ),
            tooltip: _enPausa ? 'Continuar' : 'Pausar',
            onPressed: _juego.terminado
                ? null
                : () => setState(() => _enPausa = !_enPausa),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.paper),
            tooltip: 'Reiniciar',
            onPressed: _reiniciar,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: MarcadorJuego(
                puntaje: _juego.puntaje,
                nivel: _juego.nivel,
                record: _record,
              ),
            ),
            Expanded(
              child: Padding(
                // La pista dejó de ser de 3 casilleros de ancho: ahora
                // son cuatro carriles de tres casilleros cada uno.
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Stack(
                  children: [
                    // Además de los botones, se puede arrastrar el dedo
                    // sobre la pista para cambiar de carril. Los que la
                    // probaron decían que "solo se puede hacer un
                    // movimiento": con el arrastre, cruzar dos carriles
                    // es un solo gesto en vez de dos toques justos.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: _arrastrar,
                      onHorizontalDragEnd: (_) => _arrastreAcumulado = 0,
                      child: TableroJuego(celdas: _vista),
                    ),
                    if (_juego.terminado)
                      CartelFinDeJuego(
                        puntaje: _juego.puntaje,
                        esRecord: _fueRecord,
                        onReiniciar: _reiniciar,
                      )
                    else if (_enPausa)
                      Container(
                        color: AppTheme.ink.withValues(alpha: 0.85),
                        alignment: Alignment.center,
                        child: Text('En pausa',
                            style: AppTheme.heading.copyWith(fontSize: 22)),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  BotonJuego(
                    icono: Icons.chevron_left_rounded,
                    tooltip: 'Izquierda',
                    tamano: 74,
                    onTap: () => _accion(_juego.moverIzquierda),
                  ),
                  BotonJuego(
                    icono: Icons.chevron_right_rounded,
                    tooltip: 'Derecha',
                    tamano: 74,
                    onTap: () => _accion(_juego.moverDerecha),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
