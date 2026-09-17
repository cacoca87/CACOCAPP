import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

/// El botón de "volver" de todas las pantallas de la app.
///
/// POR QUÉ EXISTE
///
/// Las pantallas de CACOCAPP se abren de dos formas distintas, y eso
/// cambia cómo se sale de ellas:
///
///  * La mayoría (Estadísticas, Descubrir, Noticias, Búsqueda Online…)
///    se INSERTAN dentro de `PantallaPrincipal` cambiando una variable,
///    sin pasar por el `Navigator`. Ahí `Navigator.pop` no sirve: no
///    hay ninguna ruta apilada que sacar, y llamarlo vacía el Navigator
///    entero y deja la pantalla en negro.
///  * Los juegos, en cambio, sí se abren con `Navigator.push`, y ahí lo
///    correcto es `Navigator.pop`.
///
/// Por eso cada pantalla recibe un `onVolver` con lo que de verdad hay
/// que hacer. El problema era que estaba escrito de dos maneras: seis
/// pantallas se protegían de que ese callback fuera nulo cayendo en
/// `Navigator.pop`, y cinco lo enchufaban crudo al botón —- y un
/// `onPressed: null` en Flutter no es "no hace nada": **apaga el
/// botón**. Si alguna de esas cinco se abriera sin pasarle el callback,
/// el botón quedaba gris y no había forma de salir de la pantalla.
///
/// Tenerlo en un solo lugar hace imposible que vuelva a quedar a medias
/// en una pantalla y no en otra.
class BotonVolver extends StatelessWidget {
  /// Lo que de verdad hay que hacer para volver. Si es `null`, se cae
  /// en `Navigator.pop` cuando haya una ruta que sacar.
  final VoidCallback? onVolver;

  /// La versión chica, para cuando el botón va dentro de una fila de la
  /// pantalla y no en la barra de arriba.
  final bool compacto;

  const BotonVolver({super.key, required this.onVolver, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        compacto ? Icons.arrow_back_ios_new : Icons.arrow_back,
        color: AppTheme.paper,
        size: compacto ? 18 : null,
      ),
      tooltip: 'Volver',
      onPressed: () => volverAtras(context, onVolver),
    );
  }
}

/// La misma decisión, para los lugares que no dibujan el botón estándar.
void volverAtras(BuildContext context, VoidCallback? onVolver) {
  if (onVolver != null) {
    onVolver();
    return;
  }
  if (Navigator.canPop(context)) Navigator.pop(context);
}
