# CACOCAPP

Reproductor de música en Flutter para Android. Reúne en una sola app cuatro
fuentes distintas y las trata a todas por igual: una biblioteca propia alojada
en Cloudflare R2, **la música que ya está guardada en el celular**, el catálogo
libre de Jamendo, y videos de YouTube reproducidos en un reproductor flotante.

Las tres primeras se mezclan en una sola lista ordenada. No hay una "sección de
música local" aparte: buscás, marcás favoritos, armás playlists y mirás las
estadísticas sin tener que saber de dónde salió cada canción.

## Qué hace

**Reproducción**
- Reproducción en segundo plano con notificación y control desde la pantalla
  bloqueada o los auriculares.
- Cola, aleatorio y repetición (una canción / toda la lista).
- Recuperación automática ante cortes de conexión, con reintentos espaciados.
- Temporizador de apagado.
- Ecualizador de bandas, realce de graves y de volumen (solo Android; usa las
  APIs nativas `android.media.audiofx` a través de un canal propio en Kotlin).

**Fuentes de música**
- **Tu Biblioteca**: archivos MP3 en un bucket de Cloudflare R2, listados por un
  Worker. Los títulos, artistas y carátulas se leen de las etiquetas ID3 reales
  del archivo, con el nombre del archivo como respaldo.
- **La música del propio celular**: se lee del índice de medios de Android y se
  mezcla con la biblioteca en la misma lista. Un filtro deja afuera lo que no es
  música --notas de voz de WhatsApp, grabaciones, tonos y alarmas-- mirando la
  carpeta, el formato, la duración y las marcas del propio Android. Si se
  saltearon archivos, la app dice cuántos: si un día falta un tema, ese número
  es la primera pista.
- **Descubrir**: búsqueda en Jamendo (catálogo Creative Commons, audio completo).
  Los resultados se comportan como cualquier otra canción: favoritos, playlists
  y descarga offline.
- **Búsqueda Online**: busca videos en YouTube y los reproduce en el reproductor
  oficial embebido, dentro de una ventana flotante que se puede arrastrar y que
  sigue sonando mientras usás el resto de la app.

**Organización**
- Playlists propias y favoritos, guardados en el dispositivo.
- Descargas para escuchar sin conexión.
- Vistas por artista y por álbum.
- Letras sincronizadas con el tiempo de la canción (formato LRC, vía lrclib).
- Estadísticas de escucha y recomendaciones según lo que más escuchás.
- Cuatro juegos clásicos (Bloques, Carrera, Serpiente y Disparos) para jugar
  mientras suena la música, sin que se corte.
- Sección de Noticias por categoría: negocios internacionales, comercio global,
  logística, cadena de suministro, contratos, tecnología y música.
- Compartir al selector nativo de Android (WhatsApp, X, Instagram, etc.).

## Cómo correrlo

Requiere [Flutter](https://docs.flutter.dev/get-started/install) (canal stable).
Verificá primero que el entorno esté completo con `flutter doctor`.

```bash
flutter pub get
flutter run                      # en un celular conectado o emulador
flutter build apk --release      # genera el APK instalable
```

## Estructura

```
lib/
  main.dart                 arranque, providers globales, bloqueo de orientación
  models/                   Song, Playlist
  providers/                estado de la app (provider)
    player_provider          cola, descargas, sesión, estadísticas
    playlist_provider        playlists y favoritos, con su persistencia
    online_video_provider    estado del video de YouTube
    audio_effects_provider   ecualizador, graves, volumen
    recommendation_engine    lógica pura de recomendaciones
  screens/                  pantallas completas
  widgets/                  componentes reutilizables
  services/                 acceso a datos y APIs externas
    drive_service            biblioteca de Cloudflare R2
    jamendo_service          búsqueda en Jamendo
    youtube_service          búsqueda en YouTube
    my_audio_handler         motor de audio (just_audio + audio_service)
    id3_cover_service        etiquetas y carátulas incrustadas en los MP3
    lyrics_service           letras sincronizadas
    noticias_service         noticias por categoría (RSS de Google Noticias)
    musica_local_service     la música guardada en el propio celular
  utils/                    funciones puras: nada de Flutter adentro, así que
                            se prueban sin necesitar un celular. Ahí vive todo
                            lo que de verdad puede fallar: la lógica de los
                            cuatro juegos, el parseo de las letras y de las
                            noticias, el filtro de música local, la búsqueda
                            que ignora tildes, la elección de qué letra
                            corresponde a qué canción, y las cuentas de dónde
                            va cada cosa en pantalla.
  styles/app_theme.dart     identidad visual
test/                       pruebas, con la misma estructura que lib/
android/app/src/main/kotlin/
                            el puente nativo: efectos de audio y lectura del
                            índice de música de Android
```

## Pruebas y calidad

```bash
flutter analyze    # análisis estático con flutter_lints
flutter test       # pruebas unitarias
dart format .      # formato
```

Los tres pasos corren automáticamente en GitHub Actions ante cada push
(`.github/workflows/flutter_ci.yml`).

Hay **529 pruebas**, en tres grupos:

**Lógica pura** (parseo, reglas, cuentas). Parseo de letras, deducción de título
y artista desde el nombre del archivo, adivinación de extensiones, motor de
recomendaciones, reglas de los cuatro juegos, el filtro que distingue música de
una nota de voz, la búsqueda que ignora tildes, y la geometría del reproductor
de video.

**Servicios**, con HTTP simulado: cliente de Jamendo, biblioteca de R2 con sus
tres respaldos, letras, carátulas, noticias, y la persistencia de playlists y
favoritos.

**Interfaz**: unas ochenta pruebas que montan widgets de verdad y comprueban lo
que se ve y lo que responde al toque. Que nada se desborde con la letra del
sistema agrandada en pantallas de 320 a 412 píxeles, que el destello al tocar no
quede tapado, que los botones de los juegos repitan al mantenerlos apretados,
que la letra sincronizada resalte el renglón correcto, y que los colores de la
paleta tengan contraste suficiente para leerse.

Varios arreglos están comprobados **a la inversa**: se vuelve a poner el error a
propósito y se verifica que la prueba lo agarre. Un test que pasa igual con el
arreglo y sin él no prueba nada, y en este proyecto ya apareció uno así (se
borró).

Lo que **no** se puede probar acá es lo que necesita un teléfono de verdad: que
el audio suene, los permisos de Android, el reproductor de YouTube (es una vista
nativa) y los efectos de audio. Eso se verifica instalando el APK.

## Decisiones de diseño que conviene conocer

**Por qué YouTube se reproduce en un WebView y no extrayendo el audio.** La app
extraía el audio directamente, pero YouTube exige desde hace un tiempo un "PO
Token" (prueba de origen) que no se puede generar de forma confiable desde una
app de terceros. En vez de pelear contra eso, se usa el reproductor oficial
embebido: no requiere extracción y por eso no se rompe.

**Por qué la app está bloqueada en vertical.** El diseño cambia de celular a
escritorio según el ancho de pantalla, y rotar un celular cruzaba ese umbral:
eso desmontaba el reproductor de video y terminaba en un cierre inesperado.
Ninguna pantalla está pensada para horizontal, así que se bloquea la rotación.

**Por qué el reproductor de YouTube lleva una `Key` fija.** Está explicado en el
encabezado de `lib/widgets/online_video_overlay.dart`. En resumen: si Flutter
deja de reconocerlo como el mismo widget, destruye el WebView y se corta la
reproducción. Hay dos reglas ahí que no conviene romper.

## Limitaciones conocidas

- Solo se probó en Android. Compila también para Windows y web, pero ninguna de
  las dos se ejecutó: en Windows no hay WebView, así que Búsqueda Online avisa
  que no está disponible en vez de romper; en web es muy probable que el
  navegador bloquee las peticiones a las fuentes externas (CORS) y no hay
  sistema de archivos para las descargas.
- El ecualizador y los efectos de audio solo funcionan en Android, y no se
  aplican al reproductor de YouTube (ese maneja su propio audio).
- Algunos videos de YouTube no permiten reproducción embebida; en esos casos la
  app lo informa y sugiere elegir otro resultado.
- **Búsqueda Online no suena con la pantalla apagada.** El reproductor de
  YouTube es una vista web, y Android la suspende al bloquear la pantalla. La
  app hace lo que se puede hacer legítimamente --levanta un servicio en primer
  plano, publica la notificación con sus controles, y le insiste al video para
  que siga sonando-- y aun así no alcanza en todos los teléfonos. Reproducir
  YouTube en segundo plano es, de hecho, una función que YouTube cobra aparte.
  Todo lo demás (la biblioteca, la música del celular, las descargas y Jamendo)
  sí suena con la pantalla apagada, porque son archivos de audio de verdad.
- **El filtro de música local es una apuesta.** Decide qué es música y qué es
  una nota de voz por la carpeta, el formato y la duración. Puede equivocarse en
  los dos sentidos. Por eso la app dice cuántos archivos salteó: ese número es
  la forma de darse cuenta.

## Historial

`CAMBIOS.md` registra en detalle cada problema investigado y cada arreglo, con
la causa de fondo de cada uno.
