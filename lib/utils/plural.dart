/// Arma textos del tipo "1 canción" / "5 canciones".
///
/// Existe porque la app tenía cuatro lugares distintos escribiendo
/// `"$cantidad canciones"` a mano, y todos decían "1 canciones" cuando
/// había una sola -- el caso más probable justo en una playlist recién
/// creada.
String contar(int cantidad, String singular, String plural) =>
    '$cantidad ${cantidad == 1 ? singular : plural}';

/// Atajo para el caso más repetido de la app.
String contarCanciones(int cantidad) =>
    contar(cantidad, 'canción', 'canciones');
