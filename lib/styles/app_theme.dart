import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identidad visual de Cacocapp.
///
/// En vez de clonar la paleta de Spotify (verde #1DB954 sobre negro
/// puro), esta identidad está pensada para el contenido real de la
/// app: rock clásico, portadas de vinilo, pósters de recital. Fondo
/// negro-café cálido en vez de negro plano, acento ámbar/cobre en vez
/// de verde, un rojo vino profundo como secundario, y una slab-serif
/// con carácter para los títulos en vez de la tipografía default.
///
/// Los nombres públicos (AppTheme.primary, AppTheme.heading, etc.) se
/// mantienen sin cambios a propósito para no tener que tocar cada
/// pantalla que ya los usa — solo cambian los valores por debajo.
///
/// (Acá se nombraba también `AppTheme.cardDecoration` como ejemplo.
/// Esa decoración se sacó porque no la usaba nadie, según explica el
/// comentario de la sección de decoraciones más abajo: el archivo se
/// contradecía consigo mismo.)
class AppTheme {
  // ===== Paleta base =====
  static const Color ink = Color(0xFF14100E); // fondo base
  static const Color surface = Color(0xFF1F1915); // tarjetas
  static const Color surfaceRaised =
      Color(0xFF2A211B); // elementos elevados / modales
  static const Color amber = Color(0xFFD9962E); // acento primario
  static const Color ember = Color(0xFFB23B3B); // acento secundario, decorativo
  static const Color paper = Color(0xFFF2EDE6); // texto principal
  static const Color mutedInk = Color(0xFF9C9186); // texto secundario
  /// Texto terciario: pistas de los buscadores, y --lo importante-- los
  /// renglones de la letra que todavía no están sonando.
  ///
  /// Era `0xFF6E6459`, y ese gris daba **3,3 de contraste** contra el
  /// fondo. El mínimo para que un texto se lea cómodo es 4,5 (la regla
  /// estándar de accesibilidad, WCAG AA), así que estaba por debajo.
  ///
  /// No es un detalle de manual: en la pantalla de la letra, los
  /// renglones que vienen DESPUÉS del que suena se pintan con este
  /// color, y son justo los que se leen para ir siguiendo la canción.
  /// A 3,3 se leen mal, y al sol directamente no se leen.
  ///
  /// El valor nuevo da **5,1** sobre el fondo y **4,6** sobre una
  /// tarjeta --los dos fondos donde se usa-- y sigue siendo un gris
  /// apagado: la diferencia se nota leyendo, no mirando.
  /// `test/styles/contraste_test.dart` comprueba la cuenta.
  static const Color faintInk = Color(0xFF8D8275);
  static const Color hairline = Color(0xFF34291F); // divisores
  static const Color danger =
      Color(0xFFE0554F); // errores/eliminar — distinto del "ember" decorativo

  // ===== Alias retrocompatibles (mismos nombres que usaba el resto del código) =====
  // Solo quedan los que el código realmente usa. Este bloque tenía
  // además `primaryDark`, `primaryLight`, `cardColor`, `textPrimary`,
  // `textSecondary`, `textMuted`, `divider` y la constante
  // `cornerRadius`, que no usaba ninguna pantalla: sobraban de una
  // versión anterior del tema y solo hacían parecer que había más
  // opciones de color de las que hay.
  static const Color background = ink;
  static const Color primary = amber;
  static const Color surfaceLight = surfaceRaised;

  // Se usa más abajo en este mismo archivo (sin el prefijo
  // `AppTheme.`), así que buscar "AppTheme.cardCornerRadius" por el
  // proyecto no la encuentra y parece muerta. No lo está.
  static const double cardCornerRadius = 10.0;

  // ===== Tipografía =====
  // Display: slab-serif con peso, para títulos y momentos de marca —
  // evoca la tipografía de tapas de vinilo de los 70s/80s.
  static TextStyle _display(
      {required double fontSize,
      required FontWeight weight,
      Color color = paper,
      double? height}) {
    return GoogleFonts.zillaSlab(
        fontSize: fontSize, fontWeight: weight, color: color, height: height);
  }

  // Cuerpo: sans limpia y muy legible, para listas y metadata densa.
  static TextStyle _body(
      {required double fontSize,
      required FontWeight weight,
      Color color = mutedInk}) {
    return GoogleFonts.inter(
        fontSize: fontSize, fontWeight: weight, color: color);
  }

  static final TextStyle heading =
      _display(fontSize: 26, weight: FontWeight.w700);
  static final TextStyle subheading =
      _display(fontSize: 17, weight: FontWeight.w600, color: paper);
  static final TextStyle body = _body(fontSize: 14, weight: FontWeight.w400);
  static final TextStyle small =
      _body(fontSize: 12, weight: FontWeight.w400, color: faintInk);
  static final TextStyle caption =
      _body(fontSize: 11, weight: FontWeight.w500, color: faintInk);

  // Estilo de marca: para el nombre "CACOCAPP" y otros momentos de marca puntuales.
  static final TextStyle wordmark =
      _display(fontSize: 20, weight: FontWeight.w700, color: paper);

  // ===== Decoraciones reutilizables =====
  //
  // Acá había además `cardDecoration`, `cardDecorationElevated` y
  // `miniPlayerDecoration`: tres decoraciones que no usaba NADIE. Cada
  // pantalla se arma su propio `BoxDecoration` a mano. Tenerlas
  // guardadas hacía creer que existía un sistema de tarjetas
  // compartido, y que cambiándolas cambiaba algo -- no cambiaba nada.
  static BoxDecoration gradientCard(List<Color> colors) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      borderRadius: BorderRadius.circular(cardCornerRadius),
    );
  }

  /// Texto para los `SnackBar` de fondo ámbar. El tema global los pinta
  /// en crema, y crema sobre ámbar da un contraste de ~1.9:1: al sol no
  /// se lee. Sobre ámbar el texto tiene que ir oscuro (~9,5:1).
  static TextStyle get textoSobreAmbar => GoogleFonts.inter(
        color: ink,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );

  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: amber,
    foregroundColor: ink,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
  );

  static ButtonStyle outlineButton = OutlinedButton.styleFrom(
    foregroundColor: paper,
    side: const BorderSide(color: Color(0x66F2EDE6)),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
  );

  /// Gradientes cálidos (ámbar → vino → café) para las tarjetas de
  /// Artistas/Álbumes/Playlists y para las carátulas de respaldo,
  /// en vez de la rueda de colores saturados genérica.
  static const List<List<Color>> gradientesTarjetas = [
    [Color(0xFFD9962E), Color(0xFF6B4312)],
    [Color(0xFFB23B3B), Color(0xFF4A1414)],
    [Color(0xFF8A5A3B), Color(0xFF2E1D12)],
    [Color(0xFFC97A2B), Color(0xFF52290C)],
    [Color(0xFF9C4A2E), Color(0xFF3A1710)],
    [Color(0xFF6E5233), Color(0xFF231A0F)],
    [Color(0xFFCF8C3A), Color(0xFF5E3510)],
    [Color(0xFF7A3E3E), Color(0xFF2C1414)],
  ];

  /// Asigna siempre el mismo gradiente de [gradientesTarjetas] a un
  /// mismo nombre (de playlist, artista, álbum, etc.) usando su hash.
  /// Antes vivía duplicado como método privado `_gradientePara` en
  /// `pantalla_principal.dart` -- movido acá porque es lógica pura de
  /// theming, no de esa pantalla en particular, y varios widgets la
  /// necesitan por igual.
  static List<Color> gradientePara(String nombre) {
    final idx = nombre.hashCode.abs() % gradientesTarjetas.length;
    return gradientesTarjetas[idx];
  }

  /// Tema completo de Material, para asignar directo en MaterialApp.
  static ThemeData get themeData {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: ink,
      primaryColor: amber,
      colorScheme: base.colorScheme.copyWith(
        primary: amber,
        secondary: ember,
        surface: surface,
        error: danger,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: paper,
        displayColor: paper,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: amber,
        inactiveTrackColor: const Color(0x33F2EDE6),
        thumbColor: paper,
        overlayColor: amber.withValues(alpha: 0.2),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: amber),
      appBarTheme: AppBarTheme(
        backgroundColor: ink,
        elevation: 0,
        iconTheme: const IconThemeData(color: paper),
        titleTextStyle: GoogleFonts.inter(
            color: paper, fontWeight: FontWeight.w600, fontSize: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceRaised,
        contentTextStyle: GoogleFonts.inter(color: paper, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
