import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/my_audio_handler.dart';
import 'providers/online_video_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'screens/pantalla_principal.dart';
import 'styles/app_theme.dart';

/// Se mantiene como variable global porque player_screen.dart la usa
/// directamente. Se asigna DENTRO de _AppBootstrapState._init(), es
/// decir, después de que runApp() ya corrió y el Activity de Android
/// ya está adjunto — nunca antes.
late MyAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // IMPORTANTE: ya no inicializamos permission_handler ni audio_service
  // aquí. Ambos necesitan el Activity de Android completamente adjunto
  // al motor de Flutter, y eso solo pasa DESPUÉS de que runApp() corre
  // al menos un frame. Por eso arrancamos la app inmediatamente con una
  // pantalla de carga y la inicialización real ocurre dentro del widget.
  runApp(const AppBootstrap());
}

/// Pantalla de arranque: se muestra brevemente mientras se inicializa
/// el audio handler (y se piden permisos en Android). Una vez listo,
/// reemplaza esta pantalla con la app completa.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  MyAudioHandler? _audioHandler;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final isDesktop = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux);

      MyAudioHandler handler;

      if (isDesktop) {
        // En Windows/macOS/Linux no existe el foreground service de
        // Android, así que usamos el handler directo.
        handler = MyAudioHandler();
      } else {
        // En Android 13+ hay que pedir el permiso de notificaciones en
        // runtime o la notificación de "reproduciendo ahora" no
        // aparece, lo que hace que el sistema sea más agresivo matando
        // el servicio en segundo plano. Ahora sí es seguro pedirlo:
        // el Activity ya está adjunto porque runApp() ya corrió.
        if (defaultTargetPlatform == TargetPlatform.android) {
          await Permission.notification.request();
        }

        // En Android/iOS esto SIEMPRE debe pasar por AudioService.init:
        // registra el foreground service + notificación + media
        // session que mantiene vivo el audio con la pantalla apagada o
        // con la app en segundo plano.
        handler = await initAudioService();
      }

      if (!mounted) return;
      audioHandler = handler;
      setState(() => _audioHandler = handler);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      // Muestra el error en pantalla en vez de quedarse en negro.
      // Esto SOLO debería aparecer si algo en la config nativa
      // (AndroidManifest, MainActivity) sigue mal.
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeData,
        home: Scaffold(
          backgroundColor: AppTheme.ink,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error iniciando el reproductor:\n$_error',
                style: TextStyle(color: AppTheme.danger, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    if (_audioHandler == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeData,
        home: Scaffold(
          backgroundColor: AppTheme.ink,
          body: const Center(
            child: CircularProgressIndicator(color: AppTheme.amber),
          ),
        ),
      );
    }

    return CACOCAPP(audioHandler: _audioHandler!);
  }
}

class CACOCAPP extends StatefulWidget {
  final MyAudioHandler audioHandler;

  const CACOCAPP({super.key, required this.audioHandler});

  @override
  State<CACOCAPP> createState() => _CACOCAPPState();
}

class _CACOCAPPState extends State<CACOCAPP> with WidgetsBindingObserver {
  // Instancias directas (no solo vía Provider) para poder llamar
  // saveSession() desde didChangeAppLifecycleState. El context de este
  // State está POR ENCIMA de donde vive el MultiProvider (que se crea
  // dentro de build), así que context.read no funcionaría aquí.
  late final PlayerProvider _playerProvider;
  late final PlaylistProvider _playlistProvider;
  final OnlineVideoProvider _onlineVideoProvider = OnlineVideoProvider();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<String>? _mensajesSub;

  @override
  void initState() {
    super.initState();
    _playerProvider = PlayerProvider(
      widget.audioHandler,
      onEmpiezaOtraReproduccion: _onlineVideoProvider.pausarPorOtraReproduccion,
    );
    _playlistProvider = PlaylistProvider();
    WidgetsBinding.instance.addObserver(this);
    _pedirPermisosDeFondo();

    // Mensajes del reproductor (ej. "se perdió la conexión") se
    // muestran como un SnackBar global, sin necesitar un BuildContext
    // de una pantalla en particular.
    _mensajesSub = widget.audioHandler.mensajes.listen((mensaje) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  /// Pide permisos que evitan que el sistema mate el reproductor en
  /// segundo plano. La exención de optimización de batería es la
  /// causa #1 de que se corte la música al bloquear pantalla en
  /// Xiaomi / Samsung / Huawei / Oppo — Spotify pide exactamente lo
  /// mismo la primera vez que se abre.
  Future<void> _pedirPermisosDeFondo() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mensajesSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Al volver a CACOCAPP (tras TikTok/X, o tras desbloquear la
      // pantalla), onAppResumed() decide si hay que reanudar por una
      // interrupción, o revivir la reproducción si el sistema cortó la
      // red mientras la pantalla estaba bloqueada.
      widget.audioHandler.onAppResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Guardamos qué canción sonaba y en qué posición, para poder
      // continuar exactamente ahí la próxima vez que se abra la app.
      _playerProvider.saveSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _playerProvider),
        ChangeNotifierProvider.value(value: _playlistProvider),
        ChangeNotifierProvider.value(value: _onlineVideoProvider),
      ],
      child: MaterialApp(
        title: 'Cacocapp',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        theme: AppTheme.themeData,
        home: const PantallaPrincipal(),
      ),
    );
  }
}