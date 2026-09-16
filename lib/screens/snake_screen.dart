import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../styles/app_theme.dart';
import '../utils/snake_logica.dart';
import '../widgets/controles_juego.dart';
import '../widgets/tablero_juego.dart';

/// La Serpiente. La lógica vive en `utils/snake_logica.dart` y está
/// cubierta por tests; acá solo se dibuja y se recogen los toques.
///
/// La música sigue sonando mientras jugás: el juego no toca el motor de
/// audio. El mini reproductor no se ve, porque esta pantalla se abre
/// como ruta propia y los controles ya ocupan la franja de abajo.
class SnakeScreen extends StatefulWidget {
  final VoidCallback? onVolver;
  const SnakeScreen({super.key, this.onVolver});

  @override
  State<SnakeScreen> createState() => _SnakeScreenState();
}

class _SnakeScreenState extends State<SnakeScreen> with WidgetsBindingObserver {
  static const _claveRecord = 'snake_record_v1';

  // Índices de color de `TableroJuego.colores`.
  static const int _colorCabeza = 1; // ámbar
  static const int _colorCuerpo = 4; // verde
  static const int _colorComida = 3; // rojo vino

  final JuegoSnake _juego = JuegoSnake();
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

  void _girar(Direccion d) {
    if (_enPausa || _juego.terminado) return;
    setState(() => _juego.girar(d));
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
        title: Text('Serpiente',
            style: AppTheme.subheading.copyWith(fontSize: 18)),
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
                etiquetaExtra: 'LARGO',
                valorExtra: _juego.largo,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Stack(
                  children: [
                    TableroJuego(
                      celdas: _juego.vista(
                        colorCabeza: _colorCabeza,
                        colorCuerpo: _colorCuerpo,
                        colorComida: _colorComida,
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
              // Igual que en Bloques: girar a los costados con la mano
              // izquierda, arriba y abajo con la derecha.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      BotonJuego(
                        icono: Icons.chevron_left_rounded,
                        tooltip: 'Izquierda',
                        // Las direcciones no se repiten: la serpiente ya
                        // avanza sola, mantener apretado no aporta nada.
                        repetible: false,
                        onTap: () => _girar(Direccion.izquierda),
                      ),
                      const SizedBox(width: 12),
                      BotonJuego(
                        icono: Icons.chevron_right_rounded,
                        tooltip: 'Derecha',
                        repetible: false,
                        onTap: () => _girar(Direccion.derecha),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      BotonJuego(
                        icono: Icons.keyboard_arrow_up_rounded,
                        tooltip: 'Arriba',
                        repetible: false,
                        onTap: () => _girar(Direccion.arriba),
                      ),
                      const SizedBox(width: 12),
                      BotonJuego(
                        icono: Icons.keyboard_arrow_down_rounded,
                        tooltip: 'Abajo',
                        repetible: false,
                        onTap: () => _girar(Direccion.abajo),
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
