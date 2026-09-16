import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../utils/app_logger.dart';
import '../utils/nombre_archivo_parser.dart';

class DriveService {
  final String baseUrl = 'https://pub-700eb414537341c79d5046ada835aea7.r2.dev';
  final String listUrl = 'https://cacocapp-audio.cacoca87.workers.dev/list';

  static List<Song>? _cache;

  // Si la ultima carga real vino del Worker o del respaldo fijo. Hace
  // falta porque `_cargar()` nunca falla hacia afuera: cuando el
  // servidor no responde devuelve la lista fija y todo sigue andando.
  // Sin esta bandera, el boton "Actualizar" avisaba "Biblioteca
  // actualizada" aunque no hubiera podido hablar con el servidor.
  static bool _ultimaCargaFueDelWorker = false;

  /// `true` si la biblioteca que se esta mostrando vino del servidor, y
  /// `false` si es la lista de respaldo que viaja dentro de la app.
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
        return canciones;
      }
    } catch (e) {
      AppLogger.w(
          'No se pudo cargar la lista dinámica, usando respaldo fijo: $e');
    }

    // Respaldo: si el Worker no responde, se arma la biblioteca con la
    // lista fija de nombres de más abajo. Es una constante de 160
    // entradas, así que esto nunca queda vacío -- antes había acá un
    // tercer respaldo para el caso "ni siquiera la lista fija dio
    // nada", que era inalcanzable y además mentía: devolvía una
    // canción titulada "Sweet Child O Mine" de "Guns N Roses" cuya URL
    // apuntaba a un MP3 de demostración genérico de otro sitio.
    _ultimaCargaFueDelWorker = false;
    final cancionesFijas = _construirCanciones(_nombresArchivosFijos);
    _cache = cancionesFijas;
    return cancionesFijas;
  }

  Future<List<String>> _obtenerListaDesdeWorker() async {
    final response =
        await http.get(Uri.parse(listUrl)).timeout(const Duration(seconds: 10));

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
