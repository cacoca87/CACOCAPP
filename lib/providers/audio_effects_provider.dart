import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_effects_service.dart';
import '../services/my_audio_handler.dart';

/// Estado y control del panel de "Audio" (ecualizador, graves, realce
/// de volumen). Aplica a CUALQUIER canción que suene por el motor de
/// audio principal (`just_audio`/`MyAudioHandler`), sin importar de
/// dónde vino -- Drive/R2, Jamendo, o una descarga -- porque son
/// efectos que Android aplica sobre la sesión de audio en sí, no
/// sobre un archivo puntual.
///
/// No aplica al video de YouTube (`OnlineVideoProvider`): ese suena
/// por el reproductor embebido de YouTube dentro de un WebView, un
/// motor de audio completamente distinto que no comparte sesión con
/// `just_audio`.
///
/// Solo tiene efecto real en Android (son APIs nativas de ese
/// framework). En otras plataformas, [disponible] queda en `false` y
/// el panel debería avisar que no está disponible ahí.
class AudioEffectsProvider extends ChangeNotifier {
  final MyAudioHandler audioHandler;

  static const _kBandasKey = 'audio_fx_bandas_v1';
  static const _kEqActivoKey = 'audio_fx_eq_activo_v1';
  static const _kGravesFuerzaKey = 'audio_fx_graves_fuerza_v1';
  static const _kGravesActivoKey = 'audio_fx_graves_activo_v1';
  static const _kVolumenGananciaKey = 'audio_fx_volumen_ganancia_v1';
  static const _kVolumenActivoKey = 'audio_fx_volumen_activo_v1';

  InfoEfectosAudio _info = InfoEfectosAudio.vacia();
  bool _cargando = false;

  bool _eqActivo = false;
  bool _gravesActivo = false;
  bool _volumenActivo = false;
  int _fuerzaGraves = 500; // rango real de Android: 0-1000
  int _gananciaVolumen = 0; // milibeles -- 0 a 1000 (0 a +10dB) en la UI

  final Map<int, int> _nivelesGuardados = {};

  StreamSubscription<int?>? _sesionSub;
  int? _ultimaSesion;

  // El provider vive tanto como la app, pero igual hay que cuidarse:
  // varios metodos siguen despues de un `await`, y notificar despues
  // de `dispose()` es un error en tiempo de ejecucion.
  bool _dispuesto = false;

  // Los sliders disparan decenas de cambios por segundo mientras se
  // arrastran. Sin el temporizador de abajo, cada uno reescribia el
  // archivo de preferencias entero (con un jsonEncode adentro) en el
  // medio del gesto.
  Timer? _guardadoPendiente;

  InfoEfectosAudio get info => _info;
  bool get cargando => _cargando;
  bool get disponible => _info.bandas.isNotEmpty;
  bool get eqActivo => _eqActivo;
  bool get gravesActivo => _gravesActivo;
  bool get volumenActivo => _volumenActivo;
  int get fuerzaGraves => _fuerzaGraves;
  int get gananciaVolumen => _gananciaVolumen;

  int nivelBanda(int indice) => _nivelesGuardados[indice] ?? 0;

  /// `true` cuando ya se le preguntó al celular por sus efectos. Sin
  /// esto el panel decía "tu dispositivo no soporta ecualizador" en el
  /// caso en que todavía no había sonado nada y nunca se preguntó.
  bool get seConsultoElDispositivo => _ultimaSesion != null;

  AudioEffectsProvider(this.audioHandler) {
    _cargarPreferencias().then((_) {
      if (_dispuesto) return;
      _sesionSub = audioHandler.player.androidAudioSessionIdStream
          .listen(_onSesionCambio);
    });
  }

  Future<void> _cargarPreferencias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _eqActivo = prefs.getBool(_kEqActivoKey) ?? false;
      _gravesActivo = prefs.getBool(_kGravesActivoKey) ?? false;
      _volumenActivo = prefs.getBool(_kVolumenActivoKey) ?? false;
      _fuerzaGraves = prefs.getInt(_kGravesFuerzaKey) ?? 500;
      _gananciaVolumen = prefs.getInt(_kVolumenGananciaKey) ?? 0;

      final bandasRaw = prefs.getString(_kBandasKey);
      if (bandasRaw != null) {
        final decoded = jsonDecode(bandasRaw) as Map<String, dynamic>;
        _nivelesGuardados
          ..clear()
          ..addAll(decoded.map((k, v) => MapEntry(int.parse(k), v as int)));
      }
    } catch (_) {}
  }

  /// Agenda el guardado en disco para dentro de medio segundo. Si
  /// llega otro cambio antes, este se descarta: asi se escribe una
  /// sola vez, cuando la persona suelta el slider, y no cincuenta
  /// veces en el medio del gesto.
  void _guardarPronto() {
    _guardadoPendiente?.cancel();
    _guardadoPendiente = Timer(
      const Duration(milliseconds: 500),
      _guardarPreferencias,
    );
  }

  Future<void> _guardarPreferencias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEqActivoKey, _eqActivo);
      await prefs.setBool(_kGravesActivoKey, _gravesActivo);
      await prefs.setBool(_kVolumenActivoKey, _volumenActivo);
      await prefs.setInt(_kGravesFuerzaKey, _fuerzaGraves);
      await prefs.setInt(_kVolumenGananciaKey, _gananciaVolumen);
      await prefs.setString(
        _kBandasKey,
        jsonEncode(_nivelesGuardados.map((k, v) => MapEntry(k.toString(), v))),
      );
    } catch (_) {}
  }

  Future<void> _onSesionCambio(int? sessionId) async {
    if (sessionId == null || sessionId == 0 || sessionId == _ultimaSesion) {
      return;
    }
    _ultimaSesion = sessionId;
    _cargando = true;
    notifyListeners();

    final info = await AudioEffectsService.instance.adjuntar(sessionId);
    if (_dispuesto) return;
    _info = info;
    _cargando = false;

    if (info.bandas.isNotEmpty) {
      // Cada vez que Android arma una sesión de audio nueva (canción
      // nueva, reconexión, etc.) los efectos vuelven a su estado por
      // defecto -- hay que volver a pedirle lo que el usuario ya
      // había configurado antes.
      for (final banda in info.bandas) {
        final nivelGuardado = _nivelesGuardados[banda.indice];
        if (nivelGuardado == null) continue;
        banda.nivel = nivelGuardado.clamp(info.nivelMinimo, info.nivelMaximo);
        await AudioEffectsService.instance
            .setNivelBanda(banda.indice, banda.nivel);
      }
      await AudioEffectsService.instance.setEcualizadorActivo(_eqActivo);

      if (info.bassBoostDisponible) {
        await AudioEffectsService.instance.setFuerzaGraves(_fuerzaGraves);
        await AudioEffectsService.instance.setGravesActivo(_gravesActivo);
      }
      if (info.realceVolumenDisponible) {
        await AudioEffectsService.instance.setGananciaVolumen(_gananciaVolumen);
        await AudioEffectsService.instance.setVolumenActivo(_volumenActivo);
      }
      if (_dispuesto) return;
    }
    notifyListeners();
  }

  Future<void> setNivelBanda(int indice, int nivel) async {
    _nivelesGuardados[indice] = nivel;
    for (final banda in _info.bandas) {
      if (banda.indice == indice) {
        banda.nivel = nivel;
        break;
      }
    }
    notifyListeners();
    await AudioEffectsService.instance.setNivelBanda(indice, nivel);
    _guardarPronto();
  }

  Future<void> toggleEcualizador() async {
    _eqActivo = !_eqActivo;
    notifyListeners();
    await AudioEffectsService.instance.setEcualizadorActivo(_eqActivo);
    _guardarPronto();
  }

  Future<void> setFuerzaGraves(int fuerza) async {
    _fuerzaGraves = fuerza;
    notifyListeners();
    await AudioEffectsService.instance.setFuerzaGraves(fuerza);
    _guardarPronto();
  }

  Future<void> toggleGraves() async {
    _gravesActivo = !_gravesActivo;
    notifyListeners();
    await AudioEffectsService.instance.setGravesActivo(_gravesActivo);
    _guardarPronto();
  }

  Future<void> setGananciaVolumen(int ganancia) async {
    _gananciaVolumen = ganancia;
    notifyListeners();
    await AudioEffectsService.instance.setGananciaVolumen(ganancia);
    _guardarPronto();
  }

  Future<void> toggleVolumen() async {
    _volumenActivo = !_volumenActivo;
    notifyListeners();
    await AudioEffectsService.instance.setVolumenActivo(_volumenActivo);
    _guardarPronto();
  }

  @override
  void dispose() {
    _dispuesto = true;
    _guardadoPendiente?.cancel();
    // Si quedaba un guardado agendado, lo escribimos ya: si no, el
    // ultimo movimiento del slider antes de cerrar se perdia.
    _guardarPreferencias();
    _sesionSub?.cancel();
    super.dispose();
  }
}
