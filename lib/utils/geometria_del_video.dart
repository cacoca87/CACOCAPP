import 'package:flutter/painting.dart' show EdgeInsets;
import 'dart:ui' show Rect, Size;

/// Dónde va el video de YouTube en la pantalla, en cada uno de sus dos
/// modos.
///
/// POR QUÉ ESTO VIVE SUELTO Y NO DENTRO DEL WIDGET
///
/// El overlay del video no se puede probar: adentro lleva un WebView,
/// que es una vista nativa de Android y no arranca fuera de un
/// teléfono. Pero lo que de verdad puede salir mal ahí no es el
/// WebView: son las cuentas de dónde poner cada cosa, y esas son
/// aritmética pura.
///
/// Y ya salieron mal antes. La barra chica del video se le montaba
/// encima al mini reproductor en los celulares con la letra del sistema
/// agrandada, porque el alto del mini reproductor estaba escrito a mano
/// acá en vez de preguntárselo a él.
///
/// Sacándolo acá se puede comprobar en pantallas que no tengo: un
/// celular angosto, uno con la barra de estado grande, una ventana
/// partida a la mitad, horizontal.
class GeometriaDelVideo {
  /// La barra fija de abajo, en modo chico.
  final Rect barra;

  /// El video dentro de esa barra.
  final Rect videoChico;

  /// El video en pantalla completa.
  final Rect videoCompleto;

  /// El hueco debajo del video en pantalla completa, donde va la letra.
  final Rect zonaDeLaLetra;

  const GeometriaDelVideo({
    required this.barra,
    required this.videoChico,
    required this.videoCompleto,
    required this.zonaDeLaLetra,
  });
}

/// Alto de la barra chica de abajo.
const double altoDeLaBarraDelVideo = 64;

const double _altoVideoChico = 48;
const double _anchoVideoChico = _altoVideoChico * 16 / 9;
const double _margenLateral = 8;

/// Alto del encabezado en pantalla completa, sin contar la barra de
/// estado del sistema.
const double _altoHeader = 64;

/// Aire que se deja debajo del video en pantalla completa para que la
/// letra tenga algo de lugar.
const double _aireParaLaLetra = 90;

/// [altoDelMiniReproductor] es 0 cuando no hay ninguna canción de la
/// biblioteca cargada: el mini reproductor no está, así que su lugar no
/// se descuenta. Tiene que venir del propio mini reproductor y no de un
/// número escrito acá, porque crece con la escala de letra del sistema.
GeometriaDelVideo calcularGeometriaDelVideo({
  required Size pantalla,
  required EdgeInsets margenesDelSistema,
  required double altoDelMiniReproductor,
}) {
  final ancho = pantalla.width;
  final alto = pantalla.height;

  // ---- MODO CHICO ----

  final topBarra = alto -
      margenesDelSistema.bottom -
      altoDelMiniReproductor -
      _margenLateral -
      altoDeLaBarraDelVideo;

  final barra = Rect.fromLTWH(
    _margenLateral,
    // En una ventana muy chica la cuenta puede dar negativo. Antes que
    // dibujar la barra fuera de la pantalla, se la pega arriba.
    topBarra.clamp(0.0, alto),
    (ancho - _margenLateral * 2).clamp(0.0, ancho),
    altoDeLaBarraDelVideo,
  );

  final videoChico = Rect.fromLTWH(
    barra.left + 8,
    barra.top + (altoDeLaBarraDelVideo - _altoVideoChico) / 2,
    _anchoVideoChico,
    _altoVideoChico,
  );

  // ---- PANTALLA COMPLETA ----

  final altoHeader = _altoHeader + margenesDelSistema.top;
  final altoDisponible = alto - altoHeader - _aireParaLaLetra;

  // El video no pasa de poco más de la mitad de la pantalla: abajo
  // tiene que quedar lugar para la letra.
  var altoVideo = altoDisponible.clamp(0.0, alto * 0.55);
  var anchoVideo = altoVideo * 16 / 9;
  // Y si a lo ancho no entra, manda el ancho y el alto sale de ahí. Así
  // la proporción 16:9 se respeta siempre: un video estirado se ve mal
  // en cualquier teléfono.
  if (anchoVideo > ancho) {
    anchoVideo = ancho;
    altoVideo = anchoVideo * 9 / 16;
  }

  final videoCompleto = Rect.fromLTWH(
    (ancho - anchoVideo) / 2,
    altoHeader,
    anchoVideo,
    altoVideo,
  );

  // La letra ocupa lo que queda. El `clamp` es lo que evita que en una
  // ventana diminuta pida un alto negativo, que no es un aviso: es un
  // error en pantalla.
  final topLetra = (videoCompleto.bottom + 12).clamp(0.0, alto);
  final zonaDeLaLetra = Rect.fromLTWH(
    0,
    topLetra,
    ancho,
    (alto - topLetra).clamp(0.0, alto),
  );

  return GeometriaDelVideo(
    barra: barra,
    videoChico: videoChico,
    videoCompleto: videoCompleto,
    zonaDeLaLetra: zonaDeLaLetra,
  );
}
