import 'package:flutter/foundation.dart';

/// Logger mínimo para reemplazar los `print()` sueltos por la app.
///
/// Por qué esto y no solo `print`:
/// - En release, `print()` sigue mandando texto a la consola del
///   dispositivo/sistema; con `debugPrint`/`kDebugMode` nos aseguramos
///   de que en producción no se filtre nada (rutas de archivos, URLs
///   internas del Worker, stack traces) a quien tenga acceso a logs
///   del sistema (ej. `adb logcat`).
/// - Tener un solo punto de entrada (`AppLogger.e/i/w`) permite después
///   enchufar Crashlytics/Sentry sin tocar cada `print` desperdigado.
///
/// Uso:
///   AppLogger.e('Error al listar descargas', error: e, stackTrace: st);
///   AppLogger.i('Biblioteca cargada: ${canciones.length} canciones');
class AppLogger {
  AppLogger._();

  static void i(String mensaje) {
    if (kDebugMode) debugPrint('[INFO] $mensaje');
  }

  static void w(String mensaje) {
    if (kDebugMode) debugPrint('[WARN] $mensaje');
  }

  static void e(String mensaje, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('[ERROR] $mensaje${error != null ? ' -> $error' : ''}');
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
  }
}
