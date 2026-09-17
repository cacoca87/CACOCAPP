/// Decide si un archivo de audio del celular es MÚSICA de verdad, o si
/// es otra cosa que no tiene por qué aparecer en la biblioteca.
///
/// POR QUÉ ES LO MÁS IMPORTANTE DE TODA ESTA PARTE
///
/// Para Android, una canción y una nota de voz de WhatsApp son lo
/// mismo: las dos son "audio" y las dos entran en el índice de medios
/// del sistema. Si la app agarra todo lo que encuentra, termina
/// pasando esto: se acaba una canción, y lo que sigue es una
/// conversación tuya sonando por el parlante. O peor: con la pantalla
/// bloqueada y el celular en el bolsillo.
///
/// Lo mismo con las grabaciones de la grabadora, los tonos de llamada,
/// los sonidos de notificación y los audios de Telegram.
///
/// CÓMO SE FILTRA
///
/// No alcanza con una sola regla: cada una se escapa por algún lado.
/// Se usan cuatro, y basta que una diga que no:
///
///   1. Lo que el propio Android ya marcó como tono, notificación,
///      alarma, podcast, grabación o audiolibro.
///   2. La CARPETA donde está. Es la señal más fuerte: las notas de voz
///      y las grabaciones viven en lugares reconocibles.
///   3. El TIPO de archivo. Las notas de voz son `.opus`, y las
///      grabaciones viejas `.amr` o `.3gp`. Ninguno de esos formatos se
///      usa para música en un celular.
///   4. Cuánto DURA. Un sonido de notificación dura dos segundos y un
///      "ahí voy" de WhatsApp, cinco.
///
/// Esta lógica vive acá, suelta y sin nada de Android adentro, para
/// poder probarla con rutas de verdad sin necesitar un celular. Es el
/// tipo de cosa que si falla no da un error: simplemente un día suena
/// algo que no tenía que sonar.
library;

/// Cuánto tiene que durar como mínimo para considerarse una canción.
///
/// 45 segundos es un punto medio a conciencia. Deja afuera los sonidos
/// de notificación, los tonos y las notas de voz cortas, que es lo que
/// más molesta. A cambio, un tema de menos de 45 segundos --una intro,
/// un corte suelto-- tampoco entra. Se prefiere perder eso antes que
/// dejar pasar una conversación.
const int duracionMinimaDeUnaCancionEnSegundos = 45;

/// Pedazos de CARPETA que descartan el archivo.
///
/// Se comparan contra la parte de la ruta **sin el nombre del
/// archivo**, y ese detalle importa más de lo que parece: antes se
/// comparaban contra la ruta entera, así que cualquier canción cuyo
/// título contuviera una de estas palabras desaparecía de la
/// biblioteca sin dejar rastro.
///
/// No es un caso rebuscado. Con la lista de abajo se perdían, entre
/// otras, `/Music/Alarma.mp3` (por "alarm"), `/Music/La Llamada.mp3`
/// (por "llamada") y `/Music/Signal.mp3` (por "signal"). Son nombres
/// de canciones de verdad.
///
/// Como nombres de CARPETA siguen sirviendo igual: nadie llama
/// "Alarmas" a la carpeta donde guarda su música.
const List<String> carpetasQueNoSonMusica = [
  // Mensajería. `/android/media/` es donde WhatsApp y Telegram guardan
  // sus cosas desde Android 11, y ahí adentro va todo lo suyo.
  'whatsapp',
  'telegram',
  'signal',
  '/android/media/',
  // Notas de voz, en español y en inglés.
  'voice note',
  'voicenote',
  'notas de voz',
  'ptt-',
  // Grabaciones.
  'recording',
  'grabacion',
  'grabación',
  'grabadora',
  'sound recorder',
  'voice recorder',
  'audio recorder',
  'easy voice',
  // Llamadas.
  'call recording',
  'llamada',
  // Sonidos del sistema.
  'ringtone',
  'notification',
  'alarm',
  '/ui/',
  'tonos',
  'timbres',
];

/// Marcas en el NOMBRE del archivo que lo descartan aunque esté en una
/// carpeta de música.
///
/// Son a propósito mucho menos que las de carpeta, y todas de las que
/// no dejan lugar a duda: ninguna canción se llama "PTT-20240115" ni
/// "Voice note 3". Las palabras sueltas como "alarma" o "llamada" NO
/// están acá justamente porque sí son nombres de canciones.
const List<String> nombresQueNoSonMusica = [
  'ptt-',
  'voice note',
  'voicenote',
  'notas de voz',
  'voice recorder',
  'sound recorder',
  'audio recorder',
  'call recording',
  'grabacion de voz',
  'grabación de voz',
];

/// Formatos que sí se usan para música. Es una lista de lo permitido y
/// no de lo prohibido a propósito: si mañana aparece un formato nuevo
/// de notas de voz, queda afuera solo, sin que nadie tenga que
/// acordarse de agregarlo.
const List<String> formatosDeMusica = [
  'mp3',
  'm4a',
  'aac',
  'flac',
  'wav',
  'ogg',
  'wma',
  'aiff',
  'alac',
];

/// Por qué se descartó un archivo. Sirve para poder contarle a la
/// persona cuántos se saltearon, y para que los tests digan qué regla
/// actuó en vez de solo "no pasó".
enum MotivoDeDescarte {
  /// Android ya lo tenía marcado como tono, alarma, grabación, etc.
  loMarcoAndroid,
  carpeta,
  formato,
  muyCorto,
}

/// `null` si el archivo es música y tiene que entrar en la biblioteca.
MotivoDeDescarte? porQueNoEsMusica({
  required String ruta,
  required int duracionSegundos,
  bool esTimbre = false,
  bool esNotificacion = false,
  bool esAlarma = false,
  bool esPodcast = false,
  bool esGrabacion = false,
  bool esAudiolibro = false,
}) {
  if (esTimbre ||
      esNotificacion ||
      esAlarma ||
      esPodcast ||
      esGrabacion ||
      esAudiolibro) {
    return MotivoDeDescarte.loMarcoAndroid;
  }

  final enMinusculas = ruta.toLowerCase().replaceAll(r'\', '/');

  // La ruta se parte en dos, y cada mitad se revisa con su propia
  // lista. Antes se buscaba todo contra la ruta entera, y eso hacía que
  // el nombre de una canción pudiera activar una regla pensada para
  // nombres de carpeta.
  final ultimaBarra = enMinusculas.lastIndexOf('/');
  final carpeta =
      ultimaBarra == -1 ? '' : enMinusculas.substring(0, ultimaBarra + 1);
  final nombre =
      ultimaBarra == -1 ? enMinusculas : enMinusculas.substring(ultimaBarra + 1);

  for (final pedazo in carpetasQueNoSonMusica) {
    if (carpeta.contains(pedazo)) return MotivoDeDescarte.carpeta;
  }

  for (final pedazo in nombresQueNoSonMusica) {
    if (nombre.contains(pedazo)) return MotivoDeDescarte.carpeta;
  }

  // Los archivos de WhatsApp llevan su marca en el propio nombre
  // (AUD-20240115-WA0001.mp3), así que se reconocen aunque alguien los
  // haya movido a la carpeta de música.
  if (RegExp(r'-wa\d{4}').hasMatch(nombre)) {
    return MotivoDeDescarte.carpeta;
  }

  final punto = nombre.lastIndexOf('.');
  final extension = punto == -1 ? '' : nombre.substring(punto + 1);
  if (!formatosDeMusica.contains(extension)) return MotivoDeDescarte.formato;

  if (duracionSegundos < duracionMinimaDeUnaCancionEnSegundos) {
    return MotivoDeDescarte.muyCorto;
  }

  return null;
}
