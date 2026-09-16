import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/player_provider.dart';
import '../styles/app_theme.dart';
import '../widgets/estado_vacio.dart';

class StatisticsScreen extends StatelessWidget {
  /// Esta pantalla se inserta directo dentro de PantallaPrincipal (no
  /// se abre con Navigator.push), así que el botón "volver" no puede
  /// usar Navigator.pop — no hay ninguna ruta apilada que sacar, y
  /// hacerlo vacía el Navigator entero (pantalla negra, hay que
  /// reabrir la app). En su lugar, quien construye esta pantalla pasa
  /// [onVolver] con lo que realmente hay que hacer (volver a Inicio).
  final VoidCallback? onVolver;

  const StatisticsScreen({super.key, this.onVolver});

  void _volver(BuildContext context) {
    if (onVolver != null) {
      onVolver!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  String _formatearTiempo(int segundos) {
    final horas = segundos ~/ 3600;
    final minutos = (segundos % 3600) ~/ 60;
    if (horas > 0) {
      return '$horas h $minutos min';
    }
    return '$minutos min';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final topSongs = player.timeListened.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = topSongs.take(10).toList();

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        title: Text('Estadísticas de escucha',
            style: AppTheme.subheading.copyWith(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.paper),
          tooltip: "Volver",
          onPressed: () => _volver(context),
        ),
      ),
      body: top.isEmpty
          ? const EstadoVacio(
              icono: Icons.bar_chart_rounded,
              mensaje: 'Empezá a escuchar música y acá vas a ver cuánto tiempo '
                  'le dedicaste a cada canción.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Tiempo dedicado por canción (Top 10)',
                  style: AppTheme.subheading.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: top.isNotEmpty
                          ? (top.first.value.toDouble() * 1.1)
                          : 10.0,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            // Buscamos de forma segura el título de la canción mediante su ID o índice
                            return BarTooltipItem(
                              _formatearTiempo(rod.toY.toInt()),
                              const TextStyle(
                                  color: AppTheme.paper,
                                  fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= top.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '#${index + 1}',
                                  style: AppTheme.small.copyWith(fontSize: 10),
                                ),
                              );
                            },
                            reservedSize: 28,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                _formatearTiempo(value.toInt()),
                                style: AppTheme.small.copyWith(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => const FlLine(
                          color: AppTheme.surfaceLight,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(top.length, (index) {
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: top[index].value.toDouble(),
                              color: AppTheme.amber,
                              width: 18,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Detalle de reproducciones',
                  style: AppTheme.subheading.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 12),
                ...top.map((entry) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      // Antes acá se mostraba `entry.key`, que es el ID
                      // interno de la canción (el nombre del archivo en el
                      // bucket), no su título. `tituloDeCancion` existe
                      // justo para esto y no la llamaba nadie.
                      player.tituloDeCancion(entry.key),
                      style: AppTheme.body
                          .copyWith(fontSize: 13, color: AppTheme.paper),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _formatearTiempo(entry.value),
                      style: AppTheme.small.copyWith(color: AppTheme.amber),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
