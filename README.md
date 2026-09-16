# CACOCAPP

Reproductor de música en Flutter para Android. Reúne en una sola app tres
fuentes distintas de música y las trata a todas por igual: una biblioteca
propia alojada en Cloudflare R2, el catálogo libre de Jamendo, y videos de
YouTube reproducidos en un reproductor flotante.

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
  utils/                    funciones puras (parseo, ayudantes)
  styles/app_theme.dart     identidad visual
test/                       pruebas unitarias
```

## Pruebas y calidad

```bash
flutter analyze    # análisis estático con flutter_lints
flutter test       # pruebas unitarias
dart format .      # formato
```

Los tres pasos corren automáticamente en GitHub Actions ante cada push
(`.github/workflows/flutter_ci.yml`).

Las pruebas cubren lógica pura y servicios con HTTP simulado: parseo de letras,
deducción de título y artista desde el nombre del archivo, adivinación de
extensiones, motor de recomendaciones, cliente de Jamendo, y la persistencia de
playlists y favoritos. **No hay pruebas de interfaz**, así que
los cambios visuales o de interacción se verifican probando la app en un
dispositivo real.

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

- Solo se probó en Android. Hay código para escritorio, pero sin verificar.
- El ecualizador y los efectos de audio solo funcionan en Android, y no se
  aplican al reproductor de YouTube (ese maneja su propio audio).
- Algunos videos de YouTube no permiten reproducción embebida; en esos casos la
  app lo informa y sugiere elegir otro resultado.

## Historial

`CAMBIOS.md` registra en detalle cada problema investigado y cada arreglo, con
la causa de fondo de cada uno.
