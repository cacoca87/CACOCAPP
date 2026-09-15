import 'package:flutter/services.dart';

/// Una banda del ecualizador: frecuencia central fija (la define el
/// hardware/firmware del celular, no nosotros) y nivel ajustable en
/// milibeles (mB -- 100 mB = 1 dB).
class BandaEcualizador {
  final int indice;
  final int frecuenciaHz;
  int nivel;

  BandaEcualizador({
    required this.indice,
    required this.frecuenciaHz,
    required this.nivel,
  });
}

/// Lo que el dispositivo reportó que soporta, al engancharse a una
/// sesión de audio: cuántas bandas de ecualizador hay (varía por
/// fabricante), el rango de nivel válido, y si bass boost / realce de
/// volumen están disponibles en este celular en particular.
class InfoEfectosAudio {
  final List<BandaEcualizador> bandas;
  final int nivelMinimo;
  final int nivelMaximo;
  final bool bassBoostDisponible;
  final bool realceVolumenDisponible;

  InfoEfectosAudio({
    required this.bandas,
    required this.nivelMinimo,
    required this.nivelMaximo,
    required this.bassBoostDisponible,
    required this.realceVolumenDisponible,
  });

  factory InfoEfectosAudio.vacia() => InfoEfectosAudio(
        bandas: [],
        nivelMinimo: 0,
        nivelMaximo: 0,
        bassBoostDisponible: false,
        realceVolumenDisponible: false,
      );
}

/// Puente a los efectos de audio NATIVOS de Android
/// (`android.media.audiofx`: Equalizer, BassBoost, LoudnessEnhancer),
/// implementados en `MainActivity.kt`. `just_audio` no trae
/// ecualizador ni normalización de volumen de fábrica -- pero sí
/// expone el ID de sesión de audio (`AudioPlayer.androidAudioSessionIdStream`),
/// que es lo que Android necesita para engancharle estos efectos
/// nativos por fuera.
///
/// Solo existe una implementación real en Android (son APIs del
/// framework de Android, no hay equivalente en Windows/Web). En
/// cualquier otra plataforma no hay ningún handler registrado del
/// lado nativo, así que todas las llamadas fallan en silencio y esta
/// clase se comporta como si el dispositivo "no soportara" nada --
/// no hace falta chequear la plataforma a mano en cada método.
class AudioEffectsService {
  AudioEffectsService._();
  static final AudioEffectsService instance = AudioEffectsService._();

  static const _canal = MethodChannel('com.caco.musicapp/audio_effects');

  Future<InfoEfectosAudio> adjuntar(int sessionId) async {
    try {
      final resultado = await _canal
          .invokeMapMethod<String, dynamic>('attach', {'sessionId': sessionId});
      if (resultado == null) return InfoEfectosAudio.vacia();

      final bandasRaw =
          (resultado['bands'] as List).cast<Map<dynamic, dynamic>>();
      return InfoEfectosAudio(
        bandas: bandasRaw
            .map((b) => BandaEcualizador(
                  indice: b['index'] as int,
                  frecuenciaHz: b['freqHz'] as int,
                  nivel: b['level'] as int,
                ))
            .toList(),
        nivelMinimo: resultado['minLevel'] as int? ?? -1500,
        nivelMaximo: resultado['maxLevel'] as int? ?? 1500,
        bassBoostDisponible: resultado['bassBoostSupported'] as bool? ?? false,
        realceVolumenDisponible:
            resultado['loudnessSupported'] as bool? ?? false,
      );
    } catch (_) {
      return InfoEfectosAudio.vacia();
    }
  }

  Future<void> setNivelBanda(int banda, int nivel) async {
    try {
      await _canal
          .invokeMethod('setBandLevel', {'band': banda, 'level': nivel});
    } catch (_) {}
  }

  Future<void> setEcualizadorActivo(bool activo) async {
    try {
      await _canal.invokeMethod('setEqualizerEnabled', {'enabled': activo});
    } catch (_) {}
  }

  Future<void> setFuerzaGraves(int fuerza) async {
    try {
      await _canal.invokeMethod('setBassBoostStrength', {'strength': fuerza});
    } catch (_) {}
  }

  Future<void> setGravesActivo(bool activo) async {
    try {
      await _canal.invokeMethod('setBassBoostEnabled', {'enabled': activo});
    } catch (_) {}
  }

  Future<void> setGananciaVolumen(int gananciaMb) async {
    try {
      await _canal.invokeMethod('setLoudnessGain', {'gainMb': gananciaMb});
    } catch (_) {}
  }

  Future<void> setVolumenActivo(bool activo) async {
    try {
      await _canal.invokeMethod('setLoudnessEnabled', {'enabled': activo});
    } catch (_) {}
  }
}
