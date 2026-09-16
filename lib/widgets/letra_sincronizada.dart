import 'package:flutter/material.dart';
import '../services/lyrics_service.dart';
import '../styles/app_theme.dart';

/// Letra que se va resaltando al ritmo de lo que suena, con la línea
/// actual en grande y el resto atenuado.
///
/// Vive acá y no dentro de una pantalla porque hay DOS lugares que la
/// necesitan y tienen que comportarse igual: la pantalla de Letra de la
/// biblioteca y el panel de abajo del video de YouTube. Lo único que
/// cambia entre las dos es de dónde sale la posición: del motor de
/// audio en un caso, del reproductor de YouTube en el otro. Por eso
/// entra como un `Stream<Duration>` y no atada a ninguno de los dos.
class LetraSincronizada extends StatefulWidget {
  final List<LineaLetra> lineas;

  /// De dónde sale el "por dónde va" la reproducción.
  final Stream<Duration> posicion;

  /// Qué hacer cuando se toca una línea. Si es `null`, las líneas no
  /// responden al toque (por ejemplo, cuando saltar no es confiable).
  final ValueChanged<Duration>? onTocarLinea;

  final EdgeInsets padding;

  const LetraSincronizada({
    super.key,
    required this.lineas,
    required this.posicion,
    this.onTocarLinea,
    this.padding = const EdgeInsets.symmetric(vertical: 140, horizontal: 28),
  });

  @override
  State<LetraSincronizada> createState() => _LetraSincronizadaState();
}

class _LetraSincronizadaState extends State<LetraSincronizada> {
  final ScrollController _scroll = ScrollController();
  int _ultimaLineaResaltada = -1;

  /// Alto aproximado de cada renglón, para calcular a dónde desplazarse.
  static const double _alturaPorLinea = 56.0;

  /// Cuándo fue la última vez que la persona movió la letra con el
  /// dedo, y cuánto se espera antes de volver a seguirla sola. Sin esta
  /// pausa no se podía leer más adelante: al cambiar de línea, la
  /// pantalla te devolvía de un tirón al renglón que sonaba.
  DateTime? _ultimoArrastre;
  static const Duration _pausaTrasArrastre = Duration(seconds: 6);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int _indiceDe(Duration posicion) {
    var indice = -1;
    for (var i = 0; i < widget.lineas.length; i++) {
      if (widget.lineas[i].tiempo <= posicion) {
        indice = i;
      } else {
        break;
      }
    }
    return indice;
  }

  void _irALinea(int indice) {
    if (indice < 0 || indice == _ultimaLineaResaltada) return;
    _ultimaLineaResaltada = indice;
    if (!_scroll.hasClients) return;
    final arrastre = _ultimoArrastre;
    if (arrastre != null &&
        DateTime.now().difference(arrastre) < _pausaTrasArrastre) {
      return;
    }
    final destino = (indice * _alturaPorLinea) - 180;
    _scroll.animateTo(
      destino.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.posicion,
      builder: (context, snapshot) {
        final indiceActual = _indiceDe(snapshot.data ?? Duration.zero);

        WidgetsBinding.instance
            .addPostFrameCallback((_) => _irALinea(indiceActual));

        return NotificationListener<ScrollNotification>(
          onNotification: (aviso) {
            if (aviso is ScrollStartNotification && aviso.dragDetails != null) {
              _ultimoArrastre = DateTime.now();
            }
            return false;
          },
          child: ListView.builder(
            controller: _scroll,
            padding: widget.padding,
            itemCount: widget.lineas.length,
            itemBuilder: (context, index) {
              final activa = index == indiceActual;
              final linea = widget.lineas[index];
              return GestureDetector(
                // `opaque` para que se pueda tocar todo el renglón, no
                // solo las letras: en las líneas cortas había que
                // apuntarle justo al texto.
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTocarLinea == null
                    ? null
                    : () => widget.onTocarLinea!(linea.tiempo),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: activa ? AppTheme.paper : AppTheme.faintInk,
                      fontSize: activa ? 22 : 18,
                      fontWeight: activa ? FontWeight.bold : FontWeight.normal,
                      height: 1.4,
                    ),
                    child: Text(linea.texto),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
