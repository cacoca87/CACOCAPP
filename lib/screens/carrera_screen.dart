import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../styles/app_theme.dart';
import '../utils/carrera_logica.dart';
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

  /// Colores del tablero: 1 es tu auto (ámbar), 2 los rivales (rojo).
  static const int _colorJugador = 1;
  static const int _colorRival = 3;

  final JuegoCarrera _juego = JuegoCarrera();
  Timer? _reloj;
  int _record = 0;
  bool _enPausa = false;
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
      if (_juego.puntaje > _record) {
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

  void _reiniciar() {
    setState(() {
      _juego.reiniciar();
      _enPausa = false;
    });
    _programarReloj();
  }

  /// Arma la matriz de colores que dibuja el tablero: los rivales más tu
  /// auto en la fila de abajo.
  List<List<int>> get _vista {
    final v = _juego.rivales
        .map((fila) => fila.map((r) => r ? _colorRival : 0).toList())
        .toList();
    v[_juego.filaJugador][_juego.carrilJugador] = _colorJugador;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        title:
            Text('Carrera', style: AppTheme.subheading.copyWith(fontSize: 18)),
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
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Stack(
                  children: [
                    TableroJuego(celdas: _vista),
                    if (_juego.terminado)
                      CartelFinDeJuego(
                        puntaje: _juego.puntaje,
                        esRecord:
                            _juego.puntaje >= _record && _juego.puntaje > 0,
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
