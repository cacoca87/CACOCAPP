import 'package:flutter/material.dart';
import '../styles/app_theme.dart';
import '../widgets/boton_volver.dart';
import 'carrera_screen.dart';
import 'disparos_screen.dart';
import 'snake_screen.dart';
import 'tetris_screen.dart';

/// Menú de los juegos. Los cuatro se abren con `Navigator.push` (a
/// diferencia del resto de las secciones, que se insertan en
/// `PantallaPrincipal`) porque cada uno ocupa la pantalla entera con sus
/// propios controles abajo, y ahí el mini reproductor estorbaría.
///
/// La música sigue sonando igual: los juegos no tocan el motor de audio.
class JuegosScreen extends StatelessWidget {
  final VoidCallback? onVolver;
  const JuegosScreen({super.key, this.onVolver});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        title:
            Text('Juegos', style: AppTheme.subheading.copyWith(fontSize: 18)),
        leading: BotonVolver(onVolver: onVolver),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Para jugar mientras escuchás: la música no se corta.',
            style: AppTheme.small,
          ),
          const SizedBox(height: 16),
          _TarjetaJuego(
            icono: Icons.grid_view_rounded,
            titulo: 'Bloques',
            descripcion:
                'Encajá las piezas que caen y completá líneas para hacerlas '
                'desaparecer. Se acelera cada 10 líneas.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TetrisScreen(
                  onVolver: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _TarjetaJuego(
            icono: Icons.directions_car_rounded,
            titulo: 'Carrera',
            descripcion:
                'Esquivá los autos que vienen de frente cambiando de carril. '
                'Cuanto más aguantás, más rápido va.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CarreraScreen(
                  onVolver: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _TarjetaJuego(
            icono: Icons.moving_rounded,
            titulo: 'Serpiente',
            descripcion:
                'Comé sin chocarte contra las paredes ni contra vos mismo. '
                'Cada bocado te hace más largo y más rápido.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SnakeScreen(
                  onVolver: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _TarjetaJuego(
            icono: Icons.arrow_upward_rounded,
            titulo: 'Disparos',
            descripcion:
                'Destruí los bloques que bajan antes de que lleguen al cañón. '
                'Podés tener hasta tres balas en el aire.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DisparosScreen(
                  onVolver: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaJuego extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  const _TarjetaJuego({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: AppTheme.ink, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: AppTheme.subheading.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(descripcion, style: AppTheme.small),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.mutedInk),
          ],
        ),
      ),
    );
  }
}
