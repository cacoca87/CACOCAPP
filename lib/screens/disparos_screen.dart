import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../styles/app_theme.dart';
import '../utils/disparos_logica.dart';
import '../widgets/controles_juego.dart';
import '../widgets/tablero_juego.dart';

/// Disparos: un cañón abajo y bloques que bajan. La lógica vive en
/// `utils/disparos_logica.dart` y está cubierta por tests; acá solo se
/// dibuja y se recogen los toques.
///
/// La música sigue sonando mientras jugás: el juego no toca el motor de
/// audio. El mini reproductor no se ve, porque esta pantalla se abre
/// como ruta propia y los controles ya ocupan la franja de abajo.
class DisparosScreen extends StatefulWidget {
  final VoidCallback? onVolver;
  const DisparosScreen({super.key, this.onVolver});

  @override
  State<DisparosScreen> createState() => _DisparosScreenState();
}

class _DisparosScreenState extends State<DisparosScreen>
    with WidgetsBindingObserver {
  static const _claveRecord = 'disparos_record_v1';

  // Índices de color de `TableroJuego.colores`.
  static const int _colorCanon = 1; // ámbar
  static const int _colorBala = 2; // ámbar claro
  static const int _colorBloque = 6; // azul

  final JuegoDisparos _juego = JuegoDisparos();
  Timer? _reloj;
  int _record = 0;
  bool _enPausa = false;
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
            Text('Disparos', style: AppTheme.subheading.copyWith(fontSize: 18)),
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Stack(
                  children: [
                    TableroJuego(
                      celdas: _juego.vista(
                        colorCanon: _colorCanon,
                        colorBala: _colorBala,
                        colorBloque: _colorBloque,
                      ),
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              // Mover con la mano izquierda, disparar con la derecha.
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
                  BotonJuego(
                    icono: Icons.arrow_upward_rounded,
                    tooltip: 'Disparar',
                    tamano: 74,
                    onTap: () => _accion(_juego.disparar),
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
