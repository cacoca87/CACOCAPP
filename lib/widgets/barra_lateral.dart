import 'package:flutter/material.dart';
import '../styles/app_theme.dart';
import '../utils/secciones.dart';
import '../utils/bibliotecas_reservadas.dart';

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
      child: ListView(
        padding: EdgeInsets.zero,
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
              // El nombre de la app también tiene que entrar al lado de
              // su ícono. Con la letra del sistema al doble, "CACOCAPP"
              // en 18 puntos se pasa 24 píxeles del ancho de la barra,
              // que es fijo. Se arregló antes lo mismo en las filas del
              // menú de abajo, y esta fila se quedó sin arreglar.
              Expanded(
                child: Text("CACOCAPP",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.wordmark
                        .copyWith(fontSize: 18, letterSpacing: 0.4)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _buildItemMenu(Icons.home_rounded, seccionBiblioteca,
              etiqueta: "Inicio"),
          _buildItemMenu(Icons.queue_music_rounded, seccionPlaylists),
          _buildItemMenu(Icons.person_rounded, seccionArtistas),
          _buildItemMenu(Icons.album_rounded, seccionAlbumes),
          _buildItemMenu(Icons.bar_chart_rounded, seccionEstadisticas),
          _buildItemMenu(Icons.videogame_asset_rounded, seccionJuegos),
          _buildItemMenu(Icons.newspaper_rounded, seccionNoticias),
          _buildItemMenu(Icons.auto_awesome_rounded, seccionRecomendaciones),
          _buildItemMenu(Icons.travel_explore_rounded, seccionDescubrir),
          _buildItemMenu(Icons.cloud_queue_rounded, seccionBuscadorOnline),
          _buildItemMenu(Icons.download_done_rounded, seccionMusicaDescargada),
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
          // La lista de bibliotecas ya no va en un `Expanded`: toda la
          // barra es una sola lista que se desliza. Con la letra del
          // sistema agrandada, los once accesos de arriba mas el
          // formulario de crear no entraban en la pantalla y el
          // contenido se desbordaba.
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bibliotecas.length,
            itemBuilder: (context, index) {
              final bib = bibliotecas[index];
              final seleccionada = bib == bibliotecaSeleccionada &&
                  seccionActiva == seccionBiblioteca;
              // Las cuatro vistas propias de la app no se pueden
              // renombrar ni borrar. Antes solo se protegian dos, asi
              // que mantener apretado "Recientes" abria un menu cuyas
              // dos opciones no hacian absolutamente nada.
              final esProtegida = nombresReservadosDeBiblioteca.contains(bib);
              // `Material` transparente alrededor: sin él, el destello
              // al tocar la fila es INVISIBLE. El ListTile pinta su
              // fondo y su destello sobre el Material más cercano, y
              // acá el más cercano queda TAPADO por el color de fondo
              // de la barra. Flutter lo avisa, pero solo se ve al
              // correr un test de pantalla: en el celular la fila
              // responde igual, solo que se siente muerta al tocarla.
              return Material(
                type: MaterialType.transparency,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    bib,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                ),
              );
            },
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
            // `Expanded` + una sola línea: el menú vive en una barra de
            // ancho fijo (240 o 260), y con la letra del sistema
            // agrandada "Música Descargada" no entraba al lado del
            // ícono. Una fila que no entra en Flutter no se acomoda
            // sola: sale con las rayas amarillas y negras de
            // desbordado.
            Expanded(
              child: Text(
                etiqueta ?? title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.body.copyWith(
                  fontSize: 14,
                  color: active ? AppTheme.paper : AppTheme.mutedInk,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
