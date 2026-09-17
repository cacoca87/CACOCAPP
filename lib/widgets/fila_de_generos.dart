import 'package:flutter/material.dart';
import '../services/jamendo_service.dart';
import '../styles/app_theme.dart';

/// La fila de géneros de la pantalla Descubrir.
///
/// Buscan por las etiquetas reales de Jamendo y no por texto, así que
/// encuentran música de ese género aunque la palabra en sí no aparezca
/// en ningún título.
///
/// POR QUÉ NO TIENE UN ALTO FIJO
///
/// Tenía uno: `40 * escala de letra, topeada en 1.6`. Buscando el mismo
/// fallo de los carruseles de Inicio --una caja que no crece tanto como
/// el texto de adentro-- se midió esto esperando un desbordado.
///
/// **No lo había**, y conviene que quede escrito para que nadie lo
/// vuelva a buscar acá. Lo que pasaba era más chico:
///
///  * con la letra normal, la caja de 40 le quedaba corta al chip, que
///    de por sí mide 48: los chips salían achatados;
///  * con la letra grande, la caja reservaba 64 para chips de 48 o 55,
///    o sea que sobraba lugar vacío.
///
/// Ni una cosa ni la otra rompen nada. Se sacó igual el número porque
/// no hacía falta: sin él, la fila mide exactamente lo que miden los
/// chips en cada tamaño de letra, y no hay ningún valor que pueda
/// quedar desfasado del contenido más adelante.
///
/// Vive aparte y es pública para poder probarla: la pantalla entera
/// necesita el motor de audio del celular, que no arranca fuera de un
/// teléfono. Eso es lo que de verdad ganó este cambio -- los tests que
/// ahora cubren que cada género mande su etiqueta de Jamendo y no su
/// nombre en pantalla, que es donde sí se puede romper algo.
class FilaDeGeneros extends StatelessWidget {
  /// El género marcado ahora, o `null` si ninguno.
  final String? generoActivo;
  final void Function(String etiqueta, String tag) onElegirGenero;

  const FilaDeGeneros({
    super.key,
    required this.generoActivo,
    required this.onElegirGenero,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: JamendoService.generos.entries.map((entry) {
          final activo = generoActivo == entry.key;
          final color =
              JamendoService.generosColores[entry.key] ?? AppTheme.amber;
          final icono = JamendoService.generosIconos[entry.key] ??
              Icons.music_note_rounded;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                icono,
                size: 16,
                color: activo ? AppTheme.paper : color,
              ),
              label: Text(
                entry.key,
                // Una sola línea: "Bandas sonoras" es el más largo, y
                // con la letra grande partía el chip en dos.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              selected: activo,
              onSelected: (_) => onElegirGenero(entry.key, entry.value),
              backgroundColor: AppTheme.surface,
              selectedColor: color,
              labelStyle: AppTheme.body.copyWith(
                fontSize: 13,
                color: activo
                    ? AppTheme.paper
                    : AppTheme.paper.withValues(alpha: 0.85),
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                    color: activo ? color : color.withValues(alpha: 0.35)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
