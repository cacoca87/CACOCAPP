import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../utils/app_logger.dart';
import 'artwork_service.dart';
import 'id3_cover_service.dart';

Future<MyAudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.caco.musicapp.channel.audio',
      androidNotificationChannelName: 'Cacocapp reproducción',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidResumeOnClick: true,
      androidShowNotificationBadge: true,
      artDownscaleWidth: 300,
      artDownscaleHeight: 300,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler with SeekHandler, QueueHandler {
  final AudioPlayer player = AudioPlayer(
    handleInterruptions: false,
    handleAudioSessionActivation: true,
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(seconds: 60),
        maxBufferDuration: Duration(minutes: 5),
        bufferForPlaybackDuration: Duration(seconds: 10),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 6),
        backBufferDuration: Duration(seconds: 30),
        prioritizeTimeOverSizeThresholds: true,
      ),
    ),
  );

  ConcatenatingAudioSource? _playlistSource;
  List<Song>? _lastSongs;

  bool _pausedByInterruption = false;
  bool _rebuilding = false;
  bool _recovering = false;
  bool _wantsToPlay = false;
  int _retryCount = 0;
  Timer? _retryTimer;
  Duration _lastKnownPosition = Duration.zero;
  int _lastKnownIndex = 0;
  DateTime? _ignoreSourceErrorsUntil;

  static const int _maxRetries = 8;

  final StreamController<String> _mensajesController =
      StreamController<String>.broadcast();
  Stream<String> get mensajes => _mensajesController.stream;

  MyAudioHandler() {
    _configureAudioSession();
    _listenForPlaybackState();
    _listenForCurrentSongIndex();
    _listenForDuration();
    _listenForPosition();
  }

  Future<void> _configureAudioSession() async {
    if (kIsWeb) return;
    final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (isDesktop) return;

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          if (event.type == AudioInterruptionType.duck) {
            await player.setVolume(0.3);
          } else if (player.playing) {
            _pausedByInterruption = true;
            await player.pause();
          }
        } else {
          await player.setVolume(1.0);
          if (_pausedByInterruption) {
            _pausedByInterruption = false;
            await play();
          }
        }
      });

      session.becomingNoisyEventStream.listen((_) async {
        _wantsToPlay = false;
        await player.pause();
        _ignoreSourceErrorsUntil =
            DateTime.now().add(const Duration(seconds: 2));
      });
    } catch (_) {}
  }

  void _listenForPosition() {
    player.positionStream.listen((p) {
      if (p > Duration.zero) _lastKnownPosition = p;
      final i = player.currentIndex;
      if (i != null) _lastKnownIndex = i;
    });
  }

  void _listenForPlaybackState() {
    player.playbackEventStream.listen(
      (event) => playbackState.add(_transformEvent(event)),
      onError: (Object e, StackTrace st) {
        AppLogger.e('Error del motor de audio', error: e);
        final ignoreUntil = _ignoreSourceErrorsUntil;
        if (ignoreUntil != null && DateTime.now().isBefore(ignoreUntil)) return;
        _scheduleRetry();
      },
    );

    player.processingStateStream.listen((s) {
      if (s == ProcessingState.ready) {
        _retryCount = 0;
        _retryTimer?.cancel();
      }
    });
  }

  void _listenForCurrentSongIndex() {
    player.currentIndexStream.listen((index) {
      final q = queue.value;
      if (index != null && index >= 0 && index < q.length) {
        _lastKnownIndex = index;
        final item = q[index];
        mediaItem.add(item);
        _actualizarCaratulaReal(index, item);
      }
    });
  }

  Future<void> _actualizarCaratulaReal(
      int index, MediaItem itemOriginal) async {
    try {
      final songs = _lastSongs;
      if (songs == null || index < 0 || index >= songs.length) return;
      final urlReproduccion = songs[index].url;

      Uri? artUri;
      final rutaEmbebida =
          await Id3CoverService.instance.getEmbeddedCoverPath(urlReproduccion);
      if (rutaEmbebida != null) {
        artUri = Uri.file(rutaEmbebida);
      } else {
        final urlItunes = await ArtworkService.instance
            .getCoverUrl(itemOriginal.title, itemOriginal.artist ?? '');
        if (urlItunes != null) artUri = Uri.tryParse(urlItunes);
      }

      if (artUri == null) return;
      if (player.currentIndex != index) return;

      final actual = mediaItem.value;
      if (actual == null || actual.id != itemOriginal.id) return;
      final actualizado = actual.copyWith(artUri: artUri);
      mediaItem.add(actualizado);

      final colaActualizada = List<MediaItem>.from(queue.value);
      if (index < colaActualizada.length &&
          colaActualizada[index].id == itemOriginal.id) {
        colaActualizada[index] = actualizado;
        queue.add(colaActualizada);
      }
    } catch (_) {}
  }

  void _listenForDuration() {
    player.durationStream.listen((d) {
      final index = player.currentIndex;
      final q = List<MediaItem>.from(queue.value);
      if (d != null && index != null && index >= 0 && index < q.length) {
        q[index] = q[index].copyWith(duration: d);
        queue.add(q);
        mediaItem.add(q[index]);
      }
    });
  }

  void _scheduleRetry() {
    if (_recovering) return;
    if (!_wantsToPlay) return;

    if (_retryCount >= _maxRetries) {
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.ready,
      ));
      _mensajesController.add(
        'Se perdió la conexión. La música se pausó — reintenta cuando tengas señal.',
      );
      return;
    }

    _retryCount++;
    final delaySeconds = (1 << (_retryCount - 1)).clamp(1, 30);

    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.buffering,
    ));

    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delaySeconds), () async {
      _recovering = true;
      // El `finally` es imprescindible: antes, si no había canciones
      // para reconstruir se salía con un `return` que se saltaba el
      // `_recovering = false` del final, y la bandera quedaba en `true`
      // PARA SIEMPRE. Como tanto `_scheduleRetry` como `_ensureAlive`
      // arrancan con "si estoy recuperando, no hago nada", eso dejaba
      // la app sin ninguna recuperación automática por el resto de la
      // sesión: se cortaba la música al perder señal y ya no volvía
      // sola nunca más. Es el mismo patrón que ya usa `_ensureAlive`.
      var huboError = false;
      try {
        final songs = _lastSongs;
        if (songs == null || songs.isEmpty) return;
        final index = _lastKnownIndex.clamp(0, songs.length - 1);
        await _buildSource(
          songs,
          initialIndex: index,
          initialPosition: _lastKnownPosition,
        );
        await player.play();
      } catch (_) {
        huboError = true;
      } finally {
        _recovering = false;
      }
      if (huboError) _scheduleRetry();
    });
  }

  Future<void> _buildSource(
    List<Song> songs, {
    required int initialIndex,
    required Duration initialPosition,
  }) async {
    _lastSongs = songs;
    final audioSources = songs.map((song) {
      return AudioSource.uri(
        Uri.parse(song.url),
        tag: MediaItem(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          // Uri.tryParse('') no devuelve null -- devuelve un Uri
          // "vacío" sin host, que flutter_cache_manager intenta pedir
          // igual y tira "No host specified in URI" en cada intento.
          artUri: song.coverUrl.isEmpty ? null : Uri.tryParse(song.coverUrl),
        ),
      );
    }).toList();

    _playlistSource = ConcatenatingAudioSource(
      children: audioSources,
      useLazyPreparation: true,
    );
    final mediaItems = audioSources.map((s) => s.tag as MediaItem).toList();
    queue.add(mediaItems);

    // Mostramos el mediaItem correcto YA, antes de siquiera intentar
    // cargar el audio. Antes, la pantalla completa del reproductor
    // (`player_screen.dart`) solo se enteraba de la canción nueva
    // cuando `player.currentIndexStream` emitía un valor -- cosa que
    // nunca pasaba si `setAudioSource` fallaba más abajo. Resultado:
    // se quedaba mostrando el título/artista de LA CANCIÓN ANTERIOR
    // (a veces una completamente distinta, de tu biblioteca) mientras
    // el audio nuevo nunca sonaba. Ahora al menos el título es
    // siempre el correcto, se pueda reproducir o no.
    final indiceInicial =
        initialIndex.clamp(0, songs.isNotEmpty ? songs.length - 1 : 0);
    if (mediaItems.isNotEmpty) {
      mediaItem.add(mediaItems[indiceInicial]);
    }

    try {
      await player.setAudioSource(
        _playlistSource!,
        initialIndex: indiceInicial,
        initialPosition: initialPosition,
        preload: true,
      );
    } catch (e, st) {
      AppLogger.e('No se pudo cargar la fuente de audio',
          error: e, stackTrace: st);
      // Antes esta excepción se perdía en silencio: la UI no mostraba
      // ningún error y la pantalla se quedaba "trabada" sin explicar
      // por qué. Ahora se avisa por el mismo canal que ya se usa para
      // "se perdió la conexión", y se vuelve a lanzar para que quien
      // llamó a esto (PlayerProvider) también se entere.
      _mensajesController.add(
        'No se pudo cargar el audio de "${mediaItems.isNotEmpty ? mediaItems[indiceInicial].title : "esta canción"}". Probá con otra.',
      );
      rethrow;
    }
  }

  Future<void> setPlaylist(
    List<Song> songs, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
    bool autoplay = true,
  }) async {
    _retryCount = 0;
    _retryTimer?.cancel();
    await _buildSource(
      songs,
      initialIndex: initialIndex,
      initialPosition: initialPosition,
    );
    if (autoplay) {
      _wantsToPlay = true;
      await player.play();
    }
  }

  Future<bool> _ensureAlive({bool autoplay = true}) async {
    if (_rebuilding || _recovering) return true;
    final songs = _lastSongs;
    if (songs == null || songs.isEmpty) return false;

    final st = player.processingState;
    final needsRebuild = player.audioSource == null ||
        st == ProcessingState.idle ||
        (st == ProcessingState.completed && !player.hasNext);
    if (!needsRebuild) return false;

    _rebuilding = true;
    try {
      final resumeIndex = _lastKnownIndex.clamp(0, songs.length - 1);
      final resumeAt =
          st == ProcessingState.completed ? Duration.zero : _lastKnownPosition;
      await _buildSource(
        songs,
        initialIndex: resumeIndex,
        initialPosition: resumeAt,
      );
      if (autoplay) {
        _wantsToPlay = true;
        await player.play();
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _rebuilding = false;
    }
  }

  Future<void> onAppResumed() async {
    _retryTimer?.cancel();
    _retryCount = 0;
    await player.setVolume(1.0);

    final revived = await _ensureAlive(autoplay: _wantsToPlay);
    if (_pausedByInterruption) {
      _pausedByInterruption = false;
      if (!revived) await play();
    } else if (_wantsToPlay && !player.playing && !revived) {
      await play();
    }
  }

  @override
  Future<void> play() async {
    _wantsToPlay = true;
    _retryCount = 0;
    if (await _ensureAlive(autoplay: true)) return;
    if (player.processingState == ProcessingState.completed) {
      if (player.hasNext) {
        await player.seekToNext();
      } else {
        await player.seek(Duration.zero);
      }
    }
    await player.play();
  }

  @override
  Future<void> pause() async {
    _wantsToPlay = false;
    _pausedByInterruption = false;
    _retryTimer?.cancel();
    await player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    if (await _ensureAlive(autoplay: _wantsToPlay)) return;
    await player.seek(position);
  }

  @override
  Future<void> stop() async {
    _wantsToPlay = false;
    _retryTimer?.cancel();
    await player.stop();
    return super.stop();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    _retryCount = 0;
    final revived = await _ensureAlive(autoplay: false);
    if (_playlistSource == null) return;
    if (index < 0 || index >= _playlistSource!.length) return;
    _lastKnownIndex = index;
    _lastKnownPosition = Duration.zero;
    await player.seek(Duration.zero, index: index);
    _wantsToPlay = true;
    if (revived || !player.playing) await player.play();
  }

  @override
  Future<void> skipToNext() async {
    _retryCount = 0;
    await _ensureAlive(autoplay: false);
    _lastKnownPosition = Duration.zero;

    if (player.hasNext) {
      await player.seekToNext();
      _wantsToPlay = true;
      await player.play();
    } else if (queue.value.isNotEmpty) {
      _wantsToPlay = false;
      await player.pause();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    _retryCount = 0;
    await _ensureAlive(autoplay: false);
    if (player.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
    } else if (player.hasPrevious) {
      await player.seekToPrevious();
    } else {
      // Primera cancion de la cola y recien empezada: "anterior" no
      // hacia nada visible. Al menos que vuelva al principio, que es
      // lo que hace cualquier reproductor.
      await player.seek(Duration.zero);
    }
    _lastKnownPosition = Duration.zero;
    _wantsToPlay = true;
    await player.play();
  }

  Future<void> setShuffle(bool enabled) async {
    await player.setShuffleModeEnabled(enabled);
    if (enabled) await player.shuffle();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.one:
        await player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
        await player.setLoopMode(LoopMode.all);
        break;
      default:
        await player.setLoopMode(LoopMode.off);
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.playPause,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: player.currentIndex,
    );
  }
}
