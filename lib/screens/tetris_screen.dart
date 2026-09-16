import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../styles/app_theme.dart';
import '../utils/tetris_logica.dart';
import '../widgets/controles_juego.dart';
import '../widgets/tablero_juego.dart';

/// Tetris. Toda la lógica vive en `utils/tetris_logica.dart` y está
/// cubierta por tests; acá solo se dibuja y se recogen los toques.
///
/// La música sigue sonando mientras jugás: el juego no toca el motor de
/// audio. El mini reproductor NO se ve acá -- esta pantalla se abre como
/// ruta propia, a diferencia del resto de las secciones, porque los
/// controles del juego ya ocupan la franja de abajo y los dos se
/// pelearían el lugar. Para cambiar de canción hay que volver.
class TetrisScreen extends StatefulWidget {
  final VoidCallback? onVolver;
  const TetrisScreen({super.key, this.onVolver});

  @override
  State<TetrisScreen> createState() => _TetrisScreenState();
}

class _TetrisScreenState extends State<TetrisScreen>
    with WidgetsBindingObserver {
  static const _claveRecord = 'tetris_record_v1';

  final JuegoTetris _juego = JuegoTetris();
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
    // Sin esto el juego seguiría corriendo (y gastando batería) después
    // de salir de la pantalla.
    _reloj?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si te vas de la app, el juego se pausa solo: volver y encontrarte
    // con que perdiste mientras no mirabas sería desagradable.
    if (state != AppLifecycleState.resumed && !_enPausa) {
      setState(() => _enPausa = true);
    }
  }

  Future<void> _cargarRecord() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _record = prefs.getInt(_claveRecord) ?? 0);
    } catch (_) {
      // Sin récord guardado se juega igual.
    }
  }

  Future<void> _guardarRecord(int puntaje) async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
    setState(_juego.bajar);
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
    // El intervalo depende del nivel, así que hay que rehacer el reloj
    // cuando el nivel cambia.
    if (_juego.nivel != _nivelDelReloj) _programarReloj();
  }

  void _accion(void Function() f) {
    if (_enPausa || _juego.terminado) return;
    setState(f);
    _revisarFinYVelocidad();
  }

  void _reiniciar() {
    setState(() {
      _juego.reiniciar();
      _enPausa = false;
    });
    _programarReloj();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        title:
            Text('Bloques', style: AppTheme.subheading.copyWith(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.paper),
          tooltip: 'Volver',
          onPressed: widget.onVolver,
        ),
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
                etiquetaExtra: 'LÍNEAS',
                valorExtra: _juego.lineasHechas,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  children: [
                    TableroJuego(celdas: _juego.vista),
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              // Mover a la izquierda de la pantalla, girar y bajar a la
              // derecha: así cada pulgar tiene lo suyo y no hay que
              // cruzar la mano, como en el aparatito original.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      BotonJuego(
                        icono: Icons.chevron_left_rounded,
                        tooltip: 'Izquierda',
                        onTap: () => _accion(_juego.moverIzquierda),
                      ),
                      const SizedBox(width: 12),
                      BotonJuego(
                        icono: Icons.chevron_right_rounded,
                        tooltip: 'Derecha',
                        onTap: () => _accion(_juego.moverDerecha),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      BotonJuego(
                        icono: Icons.keyboard_arrow_down_rounded,
                        tooltip: 'Bajar',
                        onTap: () => _accion(() => _juego.bajar()),
                      ),
                      const SizedBox(width: 12),
                      BotonJuego(
                        icono: Icons.rotate_right_rounded,
                        tooltip: 'Girar',
                        // Girar NO se repite: mantener apretado haría
                        // dar vueltas la pieza sin control.
                        repetible: false,
                        onTap: () => _accion(_juego.rotar),
                      ),
                    ],
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
