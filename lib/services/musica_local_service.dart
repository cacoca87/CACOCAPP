import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';
import '../utils/app_logger.dart';
import '../utils/filtro_musica_local.dart';

/// Cuántas canciones del celular entraron, y cuántas se dejaron afuera
/// por no ser música.
class ResultadoDeBusquedaLocal {
  final List<Song> canciones;

  /// Notas de voz, grabaciones, tonos y sonidos del sistema que se
  /// filtraron. Se cuenta para poder decírselo a la persona: si un día
  /// falta una canción suya, ese número es la primera pista de que el
  /// filtro se pasó de estricto.
  final int descartadas;

  /// `false` si la persona no dio permiso. No es un error: es una
  /// respuesta, y la app tiene que seguir andando igual con la
  /// biblioteca del servidor.
  final bool hayPermiso;

  const ResultadoDeBusquedaLocal({
    required this.canciones,
    required this.descartadas,
    required this.hayPermiso,
  });

  static const ResultadoDeBusquedaLocal sinPermiso = ResultadoDeBusquedaLocal(
    canciones: [],
    descartadas: 0,
    hayPermiso: false,
  );
}

/// Encuentra la música que ya está guardada en el celular y la convierte
/// en canciones normales de la app.
///
/// CÓMO ENCAJA CON EL RESTO
///
/// Devuelve `Song` iguales a las de la biblioteca del servidor, así que
/// se mezclan en la misma lista y todo lo demás funciona sin enterarse:
/// la búsqueda, los favoritos, las playlists, Artistas, Álbumes, las
/// estadísticas. No hay una "sección de música local" aparte, que es
/// justo lo que se pidió: que no esté una cosa en un lado y otra en
/// otro.
///
/// Lo único que las distingue es el `id`, que empieza con `local_`.
///
/// QUÉ SE APROVECHA DE LO QUE YA HABÍA
///
/// La dirección que se les pone es `file://...`, la misma forma que ya
/// usan las canciones descargadas. Gracias a eso, sin escribir una
/// línea más:
///
///  * el reproductor las toca (ya sabía reproducir archivos locales);
///  * les lee la carátula, el título y el artista de adentro del propio
///    MP3 (ver `Id3CoverService` y el arreglo de `rutaDeArchivoDe`);
///  * se pueden marcar como favoritas, meter en playlists y ver en las
///    estadísticas.
///
/// Y no gastan ni un byte de datos móviles: ya están en el teléfono.
class MusicaLocalService {
  MusicaLocalService._();
  static final MusicaLocalService instance = MusicaLocalService._();

  static const MethodChannel _canal =
      MethodChannel('com.caco.musicapp/musica_local');

  /// Solo tiene sentido en Android: el puente nativo existe nada más
  /// que ahí. En Windows o en la web no hay nada que buscar.
  static bool get disponible =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Pide permiso si hace falta. Devuelve `false` si la persona dijo
  /// que no, y en ese caso la app sigue andando con lo del servidor.
  Future<bool> pedirPermiso() async {
    if (!disponible) return false;
    try {
      // `Permission.audio` es el permiso nuevo de Android 13 en
      // adelante; `Permission.storage`, el de antes. Se prueban en ese
      // orden: en los celulares nuevos el viejo viene negado de fábrica
      // y no se puede conceder, así que preguntarlo primero daría un
      // "no" que no significa nada.
      if (await Permission.audio.isGranted) return true;
      if (await Permission.storage.isGranted) return true;

      if (await Permission.audio.request().isGranted) return true;
      return await Permission.storage.request().isGranted;
    } catch (e) {
      AppLogger.w('No se pudo pedir el permiso de música local: $e');
      return false;
    }
  }

  /// Busca la música del celular. Si [pedirPermisoSiFalta] es `false`,
  /// no molesta con el cartel del sistema: solo mira si ya lo tiene.
  ///
  /// Se puede llamar cuantas veces se quiera: Android mantiene su
  /// índice al día solo, así que volver a preguntar es lo único que
  /// hace falta para ver lo que se agregó después.
  Future<ResultadoDeBusquedaLocal> buscar(
      {bool pedirPermisoSiFalta = true}) async {
    if (!disponible) return ResultadoDeBusquedaLocal.sinPermiso;

    final tienePermiso = pedirPermisoSiFalta
        ? await pedirPermiso()
        : (await Permission.audio.isGranted ||
            await Permission.storage.isGranted);
    if (!tienePermiso) return ResultadoDeBusquedaLocal.sinPermiso;

    try {
      final crudas = await _canal.invokeListMethod<Map<dynamic, dynamic>>(
        'listar',
      );
      if (crudas == null) {
        return const ResultadoDeBusquedaLocal(
            canciones: [], descartadas: 0, hayPermiso: true);
      }
      return _armarCanciones(crudas);
    } catch (e) {
      AppLogger.w('No se pudo leer la música del celular: $e');
      return const ResultadoDeBusquedaLocal(
          canciones: [], descartadas: 0, hayPermiso: true);
    }
  }

  ResultadoDeBusquedaLocal _armarCanciones(List<Map<dynamic, dynamic>> crudas) {
    final canciones = <Song>[];
    var descartadas = 0;

    for (final cruda in crudas) {
      final ruta = (cruda['ruta'] as String?) ?? '';
      if (ruta.isEmpty) continue;

      final duracionMs = (cruda['duracionMs'] as num?)?.toInt() ?? 0;

      // La decisión de qué es música vive en `utils/filtro_musica_local`
      // y está cubierta por tests con rutas reales de notas de voz.
      final motivo = porQueNoEsMusica(
        ruta: ruta,
        duracionSegundos: duracionMs ~/ 1000,
        esTimbre: cruda['esTimbre'] == true,
        esNotificacion: cruda['esNotificacion'] == true,
        esAlarma: cruda['esAlarma'] == true,
        esPodcast: cruda['esPodcast'] == true,
        esGrabacion: cruda['esGrabacion'] == true,
        esAudiolibro: cruda['esAudiolibro'] == true,
      );
      if (motivo != null) {
        descartadas++;
        continue;
      }

      canciones.add(cancionDesdeElCelular(
        id: (cruda['id'] as num?)?.toInt() ?? 0,
        titulo: (cruda['titulo'] as String?) ?? '',
        artista: (cruda['artista'] as String?) ?? '',
        album: (cruda['album'] as String?) ?? '',
        ruta: ruta,
      ));
    }

    return ResultadoDeBusquedaLocal(
      canciones: canciones,
      descartadas: descartadas,
      hayPermiso: true,
    );
  }
}

/// Arma la `Song` a partir de lo que informa Android.
///
/// Está suelta (y no adentro de la clase) para poder probarla sin
/// celular: es donde se decide qué se muestra cuando el archivo no
/// tiene bien puestos sus datos, que es la mitad de los MP3 que andan
/// dando vueltas.
Song cancionDesdeElCelular({
  required int id,
  required String titulo,
  required String artista,
  required String album,
  required String ruta,
}) {
  final limpioTitulo = titulo.trim();
  final limpioArtista = artista.trim();
  final limpioAlbum = album.trim();

  return Song(
    // El prefijo evita que choque con un `r2_...` o un `jamendo_...`,
    // y deja saber de un vistazo de dónde salió cada una.
    id: 'local_$id',
    // Si el archivo no trae título, se usa el nombre del archivo sin la
    // extensión: es lo que muestra cualquier reproductor, y es mejor
    // que un "Desconocido" en una fila que la persona sí reconoce.
    title: limpioTitulo.isNotEmpty ? limpioTitulo : _nombreDelArchivo(ruta),
    // "<unknown>" es literalmente lo que devuelve Android cuando el MP3
    // no dice quién lo toca. Mostrarlo tal cual quedaría raro en medio
    // de la lista.
    artist:
        _esDesconocido(limpioArtista) ? 'Artista Desconocido' : limpioArtista,
    album: _esDesconocido(limpioAlbum) ? '' : limpioAlbum,
    // La misma forma que usan las canciones descargadas, para que el
    // reproductor y el lector de carátulas funcionen sin cambios.
    url: Uri.file(ruta).toString(),
    coverUrl: '',
  );
}

bool _esDesconocido(String valor) =>
    valor.isEmpty || valor == '<unknown>' || valor.toLowerCase() == 'unknown';

String _nombreDelArchivo(String ruta) {
  final nombre = ruta.split(Platform.pathSeparator).last.split('/').last;
  final punto = nombre.lastIndexOf('.');
  final sinExtension = punto <= 0 ? nombre : nombre.substring(0, punto);
  return sinExtension.trim().isEmpty ? 'Sin título' : sinExtension.trim();
}

/// Abre la pantalla de ajustes de la app, donde se puede dar el permiso
/// a mano.
///
/// Hace falta porque Android deja de preguntar después de dos "no": a
/// partir de ahí, pedir el permiso desde la app no muestra nada y
/// devuelve "denegado" al instante. La única salida son los ajustes del
/// sistema, y nadie sabe de memoria dónde quedan.
///
/// Vive acá y no en la pantalla para que el resto de la app no tenga
/// que saber nada de cómo se manejan los permisos.
Future<void> abrirAjustesParaDarElPermiso() async {
  try {
    await openAppSettings();
  } catch (e) {
    AppLogger.w('No se pudieron abrir los ajustes de la app: $e');
  }
}
