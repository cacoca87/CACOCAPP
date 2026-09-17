import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../utils/app_logger.dart';
import '../utils/nombre_archivo_parser.dart';

class DriveService {
  // Mismo patrón que `LyricsService`, `JamendoService`, `NoticiasService`
  // y `ArtworkService`: el cliente HTTP entra por el constructor para
  // poder probar esta clase sin red real. Era el único servicio que no
  // lo tenía, y por eso el respaldo de la biblioteca --que es lo que se
  // ve cuando no hay señal-- nunca lo comprobó ningún test.
  DriveService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  final String baseUrl = 'https://pub-700eb414537341c79d5046ada835aea7.r2.dev';
  final String listUrl = 'https://cacocapp-audio.cacoca87.workers.dev/list';

  /// Con qué nombre se guarda en el celular la última lista que SÍ vino
  /// del servidor.
  static const String _claveListaGuardada = 'drive_lista_v1';

  // Por instancia y no `static`, igual que en los otros servicios: la
  // app crea una sola, así que se comporta igual, pero deja de depender
  // del orden en que corren los tests.
  List<Song>? _cache;

  // De dónde salió la biblioteca que se está mostrando. Hace falta
  // porque `_cargar()` nunca falla hacia afuera: cuando el servidor no
  // responde devuelve un respaldo y todo sigue andando. Sin esto, el
  // botón "Actualizar" avisaba "Biblioteca actualizada" aunque no
  // hubiera podido hablar con el servidor.
  bool _ultimaCargaFueDelWorker = false;

  /// `true` si la biblioteca que se está mostrando vino del servidor, y
  /// `false` si es un respaldo.
  bool get listaVieneDelWorker => _ultimaCargaFueDelWorker;

  static const List<String> _artistasQueVanPrimero = [
    'Bruce Springsteen',
    'Dire Straits',
    'Los Pericos',
    'Marc Anthony',
    'Metallica',
    'The Traveling Wilburys Collection',
  ];

  Future<List<Song>> obtenerCanciones() async {
    if (_cache != null) return _cache!;
    return _cargar();
  }

  Future<List<Song>> refrescarCanciones() async {
    _cache = null;
    return _cargar();
  }

  Future<List<Song>> _cargar() async {
    try {
      final nombresArchivos = await _obtenerListaDesdeWorker();
      final canciones = _construirCanciones(nombresArchivos);
      if (canciones.isNotEmpty) {
        _ultimaCargaFueDelWorker = true;
        _cache = canciones;
        // Se guarda para la próxima vez que no haya señal. No se espera:
        // la biblioteca ya está lista y esto no tiene que demorarla.
        _guardarLista(nombresArchivos);
        return canciones;
      }
    } catch (e) {
      AppLogger.w('No se pudo consultar el servidor: $e');
    }

    _ultimaCargaFueDelWorker = false;

    // PRIMER RESPALDO: la última lista que SÍ vino del servidor, tal
    // como estaba la última vez que hubo señal.
    //
    // Antes esto no existía y se pasaba directo a la lista fija de más
    // abajo. Esa lista NO está mal --sus canciones están todas en el
    // servidor y se reproducen perfecto-- pero está INCOMPLETA: es una
    // foto del bucket del día en que se escribió, y todo lo que se
    // subió después no figura. Los temas de Amén, por ejemplo.
    //
    // Así que sin señal veías una biblioteca a la que le faltaban
    // canciones que sí tenés, sin ninguna forma de saber cuáles. La
    // lista guardada arregla eso porque se actualiza sola cada vez que
    // la app habla con el servidor.
    final guardada = await _leerListaGuardada();
    if (guardada != null && guardada.isNotEmpty) {
      final canciones = _construirCanciones(guardada);
      _cache = canciones;
      return canciones;
    }

    // SEGUNDO RESPALDO: la lista fija que viaja dentro de la app.
    //
    // NO SE BORRA, y conviene dejarlo escrito para que a nadie se le
    // ocurra al ver 160 líneas de nombres y pensar que son relleno:
    // esas canciones ESTÁN en el servidor y se reproducen perfecto. Es
    // una foto real del bucket, solo que le faltan las que se subieron
    // después de armarla.
    //
    // Sirve para la primerísima apertura sin señal, cuando todavía no
    // hubo ninguna vez con internet y no hay nada guardado: ahí es esto
    // o una pantalla vacía. Con 160 entradas, nunca queda vacío.
    //
    // (Antes había acá un TERCER respaldo, para el caso "ni siquiera la
    // lista fija dio nada". Ese sí era inútil y además mentía: devolvía
    // una canción titulada "Sweet Child O Mine" de "Guns N Roses" cuya
    // dirección apuntaba a un MP3 de demostración de otro sitio.)
    final cancionesFijas = _construirCanciones(_nombresArchivosFijos);
    _cache = cancionesFijas;
    return cancionesFijas;
  }

  Future<void> _guardarLista(List<String> nombres) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_claveListaGuardada, nombres);
    } catch (_) {
      // Si no se pudo guardar no pasa nada grave: la próxima vez sin
      // señal se cae en la lista fija, como antes.
    }
  }

  Future<List<String>?> _leerListaGuardada() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_claveListaGuardada);
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _obtenerListaDesdeWorker() async {
    final response = await _client
        .get(Uri.parse(listUrl))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('El Worker respondió ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as List;
    return decoded
        .map((item) => (item as Map<String, dynamic>)['name'] as String)
        .toList();
  }

  List<Song> _construirCanciones(List<String> nombresArchivos) {
    List<Song> cancionesProcesadas = [];

    for (int i = 0; i < nombresArchivos.length; i++) {
      String archivoCompleto = nombresArchivos[i];
      String fileId = 'r2_$archivoCompleto';

      String nombreLimpio = archivoCompleto
          .replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '')
          .trim();

      // La deducción vive en `utils/nombre_archivo_parser.dart` para
      // poder probarla con tests sin salir a la red.
      final deducido = deducirTituloYArtista(
        nombreLimpio,
        artistasQueVanPrimero: _artistasQueVanPrimero,
      );
      final String title = deducido.titulo;
      final String artist = deducido.artista;

      String urlStreamingDirecto =
          '$baseUrl/${Uri.encodeComponent(archivoCompleto)}';

      cancionesProcesadas.add(
        Song(
          id: fileId,
          title: title,
          artist: artist,
          album: artist,
          coverUrl: '',
          url: urlStreamingDirecto,
        ),
      );
    }

    return cancionesProcesadas;
  }

  final List<String> _nombresArchivosFijos = const [
    "14 Years.mp3",
    "A Face In The Crowd.mp3",
    "A Kind Of Magic - Queen.mp3",
    "Ain't It Fun.mp3",
    "All I Ever Wanted.mp3",
    "Alright For Now.mp3",
    "Always On The Run.mp3",
    "Amazing.mp3",
    "Anything Goes - Guns N' Roses.mp3",
    "Are You Gonna Go My Way.mp3",
    "Attitude - Guns N' Roses.mp3",
    "Back Off Bitch - Guns N' Roses.mp3",
    "Bad Apples - Guns N' Roses.mp3",
    "Bad Obsession - Guns N' Roses.mp3",
    "Beating Around the Bush - ACDC.mp3",
    "Believe.mp3",
    "Bicycle Race - Queen.mp3",
    "Big Dumb Sex - Guns N' Roses.mp3",
    "Black Dog - Remaster - Led Zeppelin.mp3",
    "Black Girl.mp3",
    "Black Leather.mp3",
    "Bohemian Rhapsody.mp3",
    "Boogie Man.mp3",
    "Breakdown - Guns N' Roses.mp3",
    "Breed.mp3",
    "Butterfly.mp3",
    "Civil War - Guns N' Roses.mp3",
    "Coma - Guns N' Roses.mp3",
    "Come As You Are.mp3",
    "Come On And Love Me.mp3",
    "Crazy.mp3",
    "Cryin'.mp3",
    "Dead Horse - Guns N' Roses.mp3",
    "Depending On You.mp3",
    "Don't Cry (original)- Guns N' Roses.mp3",
    "Don't Cry - Guns N' Roses.mp3",
    "Don't Damn Me - Guns N' Roses.mp3",
    "Don't Stop Me Now - Queen.mp3",
    "Double Talkin' Jive - Guns N' Roses.mp3",
    "Down On The Farm - Guns N' Roses.mp3",
    "Drain You.mp3",
    "Dust N' Bones - Guns N' Roses.mp3",
    "Eat The Rich.mp3",
    "Eleutheria.mp3",
    "Endless, Nameless.mp3",
    "Fat Bottomed Girls - Queen.mp3",
    "Fever.mp3",
    "Fields Of Joy - Reprise.mp3",
    "Fields Of Joy.mp3",
    "Five Years - David Bowie - 2012 Remaster.mp3",
    "Flesh.mp3",
    "Flowers For Zoë.mp3",
    "Friends Will Be Friends - Queen.mp3",
    "Garden Of Eden - Guns N' Roses.mp3",
    "Get A Grip.mp3",
    "Get In The Ring - Guns N' Roses.mp3",
    "Get It Hot - ACDC.mp3",
    "Girls Got Rhythm - ACDC.mp3",
    "Going to California - Led Zeppelin - Remaster.mp3",
    "Good Times Bad Times - Led Zeppelin - Remaster.mp3",
    "Gotta Love It.mp3",
    "Hair Of The Dog - Guns N' Roses.mp3",
    "Hang on to Yourself - David Bowie - 2012 Remaster.mp3",
    "Heaven Help.mp3",
    "Highway to Hell - ACDC.mp3",
    "Human Being - Guns N' Roses.mp3",
    "I Want It All - Queen.mp3",
    "I Want To Break Free - Queen.mp3",
    "I Won't Back Down.mp3",
    "If You Want Blood (You've Got It) - ACDC.mp3",
    "Immigrant Song - Led Zeppelin - Remaster.mp3",
    "In the Lap of the Gods...Revisited - Queen.mp3",
    "Intro.mp3",
    "Is There Any Love In Your Heart.mp3",
    "It Ain't Easy - 2012 Remaster.mp3",
    "It Ain't Over 'Til It's Over.mp3",
    "It's So Easy - Guns N' Roses.mp3",
    "Just Be A Woman.mp3",
    "Kashmir - Led Zeppelin Remaster.mp3",
    "Killer Queen - Queen.mp3",
    "Knockin' On Heaven's Door - Guns N' Roses.mp3",
    "Lady Stardust - 2012 Remaster.mp3",
    "Line Up.mp3",
    "Lithium.mp3",
    "Live And Let Die - Guns N' Roses.mp3",
    "Livin' On The Edge.mp3",
    "Locomotive (Complicity) - Guns N' Roses.mp3",
    "Look At Your Game, Girl - Guns N' Roses.mp3",
    "Lounge Act.mp3",
    "Love Hungry Man - ACDC.mp3",
    "Love Is A Long Road.mp3",
    "Moonage Daydream - 2012 Remaster.mp3",
    "More Than Anything In This World.mp3",
    "Mr. Brownstone - Guns N' Roses.mp3",
    "My Love.mp3",
    "My Michelle - Guns N' Roses.mp3",
    "My World - Guns N' Roses.mp3",
    "New Rose - Guns N' Roses.mp3",
    "Night Prowler - ACDC.mp3",
    "Nightrain - Guns N' Roses.mp3",
    "November Rain - Guns N' Roses.mp3",
    "On A Plain.mp3",
    "Out Ta Get Me - Guns N' Roses.mp3",
    "Over the Hills and Far Away - Led Zeppelin - Remaster.mp3",
    "Paradise City - Guns N' Roses.mp3",
    "Perfect Crime - Guns N' Roses.mp3",
    "Polly.mp3",
    "Pretty Tied Up (The Perils Of Rock N' Roll Decadence) - Guns N' Roses.mp3",
    "Radio Ga Ga - Queen.mp3",
    "Ramble On - Remaster - Led Zeppelin.mp3",
    "Raw Power - Guns N' Roses.mp3",
    "Right Next Door To Hell - Guns N' Roses.mp3",
    "Rock 'n' Roll Suicide - 2012 Remaster.mp3",
    "Rock and Roll - Led Zeppelin.mp3",
    "Rocket Queen - Guns N' Roses.mp3",
    "Runnin' Down A Dream.mp3",
    "Save Me - Queen.mp3",
    "Shot Down in Flames - ACDC.mp3",
    "Shotgun Blues - Guns N' Roses.mp3",
    "Shut Up And Dance.mp3",
    "Since I Don't Have You - Guns N' Roses.mp3",
    "Sister.mp3",
    "Smells Like Teen Spirit.mp3",
    "So Fine - Guns N' Roses.mp3",
    "Somebody To Love - Queen.mp3",
    "Something In The Way.mp3",
    "Soul Love - 2012 Remaster.mp3",
    "Stairway to Heaven - Led Zepellin.mp3",
    "Stand By My Woman.mp3",
    "Star - 2012 Remaster.mp3",
    "Starman - 2012 Remaster.mp3",
    "Stop Draggin' Around.mp3",
    "Suffragette City - 2012 Remaster.mp3",
    "Sugar.mp3",
    "Sweet Child O' Mine - Guns N' Roses.mp3",
    "Territorial Pissings.mp3",
    "The Apartment Song.mp3",
    "The Difference Is Why.mp3",
    "The Garden.mp3",
    "The Miracle - Queen.mp3",
    "The Show Must Go On - Queen.mp3",
    "Think About You - Guns N' Roses.mp3",
    "Touch Too Much - ACDC.mp3",
    "Under Pressure (feat. David Bowie) - Queen.mp3",
    "Walk All Over You.mp3",
    "Walk On Down.mp3",
    "We Will Rock You - Queen.mp3",
    "Welcome To The Jungle - Guns N' Roses.mp3",
    "What Goes Around Comes Around.mp3",
    "What The .... Are We Saying_.mp3",
    "When The Morning Turns To Night.mp3",
    "Whole Lotta Love - Remaster.mp3",
    "Yer So Bad.mp3",
    "Yesterdays - Guns N' Roses.mp3",
    "You Ain't The First - Guns N' Roses.mp3",
    "You Can't Put Your Arms Around A Memory - Guns N' Roses.mp3",
    "You Could Be Mine - Guns N' Roses.mp3",
    "You're Crazy - Guns N' Roses.mp3",
    "You're My Best Friend - Queen.mp3",
    "Ziggy Stardust - 2012 Remaster.mp3",
    "Zombie Zoo.mp3"
  ];
}
