import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

class BarraLateral extends StatelessWidget {
  final String seccionActiva;
  final String bibliotecaSeleccionada;
  final List<String> bibliotecas;
  final TextEditingController controladorNuevaBib;
  final Function(String) onCambiarSeccion;
  final Function(String) onSeleccionarBiblioteca;
  final VoidCallback onCrearBiblioteca;
  final bool esDrawer;
  final Function(String)? onEliminarBiblioteca;

  const BarraLateral({
    super.key,
    required this.seccionActiva,
    required this.bibliotecaSeleccionada,
    required this.bibliotecas,
    required this.controladorNuevaBib,
    required this.onCambiarSeccion,
    required this.onSeleccionarBiblioteca,
    required this.onCrearBiblioteca,
    this.esDrawer = false,
    this.onEliminarBiblioteca,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: esDrawer ? 260 : 240,
      color: AppTheme.ink,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.graphic_eq_rounded,
                    color: AppTheme.ink, size: 18),
              ),
              const SizedBox(width: 10),
              Text("CACOCAPP",
                  style: AppTheme.wordmark
                      .copyWith(fontSize: 18, letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: 28),
          _buildItemMenu(Icons.home_rounded, "Tu Biblioteca",
              etiqueta: "Inicio"),
          _buildItemMenu(Icons.queue_music_rounded, "Playlists"),
          _buildItemMenu(Icons.person_rounded, "Artistas"),
          _buildItemMenu(Icons.album_rounded, "Álbumes"),
          _buildItemMenu(Icons.bar_chart_rounded, "Estadísticas"),
          _buildItemMenu(Icons.videogame_asset_rounded, "Juegos"),
          _buildItemMenu(Icons.newspaper_rounded, "Noticias"),
          _buildItemMenu(Icons.auto_awesome_rounded, "Recomendaciones"),
          _buildItemMenu(Icons.travel_explore_rounded, "Descubrir"),
          _buildItemMenu(Icons.cloud_queue_rounded, "Buscador Online"),
          _buildItemMenu(Icons.download_done_rounded, "Música Descargada"),
          const Divider(color: AppTheme.hairline, height: 32),
          Text("Crear biblioteca",
              style: AppTheme.caption
                  .copyWith(color: AppTheme.mutedInk, letterSpacing: 0.6)),
          const SizedBox(height: 10),
          TextField(
            controller: controladorNuevaBib,
            style: AppTheme.body.copyWith(fontSize: 13, color: AppTheme.paper),
            decoration: InputDecoration(
              hintText: "Nombre...",
              hintStyle: AppTheme.body
                  .copyWith(fontSize: 12, color: AppTheme.faintInk),
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                onCrearBiblioteca();
                if (esDrawer) Navigator.pop(context);
              },
              style: AppTheme.primaryButton,
              child: const Text("CREAR"),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.builder(
              itemCount: bibliotecas.length,
              itemBuilder: (context, index) {
                final bib = bibliotecas[index];
                final seleccionada = bib == bibliotecaSeleccionada &&
                    seccionActiva == "Tu Biblioteca";
                final esProtegida =
                    bib == "Principal (Drive)" || bib == "Favoritos";
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    bib,
                    style: AppTheme.body.copyWith(
                      fontSize: 14,
                      color: seleccionada ? AppTheme.amber : AppTheme.mutedInk,
                      fontWeight:
                          seleccionada ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  onTap: () {
                    onSeleccionarBiblioteca(bib);
                    if (esDrawer) Navigator.pop(context);
                  },
                  onLongPress: (esProtegida || onEliminarBiblioteca == null)
                      ? null
                      : () => onEliminarBiblioteca!(bib),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// [etiqueta] permite mostrar un texto distinto al de [seccionActiva]
  /// sin cambiar la clave interna que usa el resto de la app.
  Widget _buildItemMenu(IconData icon, String title, {String? etiqueta}) {
    final bool active = seccionActiva == title;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onCambiarSeccion(title),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon,
                color: active ? AppTheme.amber : AppTheme.mutedInk, size: 20),
            const SizedBox(width: 14),
            Text(
              etiqueta ?? title,
              style: AppTheme.body.copyWith(
                fontSize: 14,
                color: active ? AppTheme.paper : AppTheme.mutedInk,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
