# Por qué la aplicación mostró una letra con insultos

**Informe técnico — Proyecto CACOCAPP**
Autor del informe: el desarrollador de la aplicación
Fecha: 17 de septiembre de 2026

---

## Resumen

Durante una demostración de la aplicación se vio en pantalla la letra de
una canción con contenido ofensivo, en inglés, sobre una canción
cristiana en español.

**Ese texto no fue escrito, elegido ni cargado por el alumno.** Fue el
resultado de un error de emparejamiento entre la canción que sonaba y
una base de datos pública de letras. Este informe explica cómo ocurrió,
por qué ocurrió y cuándo se corrigió.

Todo lo que se afirma acá se puede comprobar de forma independiente en
el historial público del proyecto, que tiene fecha y hora y no se puede
modificar hacia atrás sin que quede rastro.

---

## 1. De dónde salen las letras

La aplicación **no contiene ninguna letra guardada**. No hay un archivo
con letras dentro del proyecto.

Cuando el usuario abre la letra de una canción, la aplicación le
pregunta a un servicio público de internet llamado **lrclib.net** —una
base de datos comunitaria de letras sincronizadas, gratuita y abierta—
con esta forma:

> *"¿Cuál es la letra de la canción que se llama X, del artista Y?"*

Lo que ese servicio devuelve es lo que se muestra en pantalla. La
aplicación es el intermediario, no el autor.

Se puede verificar en el código, en el archivo
`lib/services/lyrics_service.dart`:

```
https://lrclib.net/api/search?...
```

---

## 2. Qué salió mal, con los números exactos

El problema fue que dos canciones distintas se parecían demasiado en los
dos únicos datos que se usaban para identificarlas:

| | Canción que sonaba | Lo que devolvió la base de datos |
|---|---|---|
| **Título** | Amén | AmEN! |
| **Artista** | Amén (pop-rock peruano) | Bring Me the Horizon (metalcore británico) |
| **Duración** | 188 segundos | 189,5 segundos |
| **Idioma** | Español | Inglés |

**La diferencia entre ambas era de un segundo y medio.**

El filtro que la aplicación usaba en ese momento comparaba el título y
la duración. Con un segundo y medio de diferencia y un título casi
idéntico, la canción equivocada pasó el filtro, y la aplicación mostró
esa letra con total seguridad, sin ninguna advertencia.

La canción "AmEN!" de Bring Me the Horizon contiene lenguaje explícito.
Ese es el texto que se vio en pantalla.

---

## 3. Cuándo se detectó y se corrigió

El error se detectó probando la aplicación y se corrigió el mismo día.
Quedó registrado en dos puntos del historial del proyecto:

| Registro | Fecha y hora | Qué se hizo |
|---|---|---|
| `445c927` | 16/09/2026 16:03 | Primer filtro: se deja de tomar el primer resultado a ciegas y se compara la duración |
| `f77ca59` | 16/09/2026 18:42 | **Corrección definitiva**: se exige además que coincida el artista |

El texto del registro `f77ca59`, escrito en el momento de corregirlo,
dice literalmente:

> *"Llegó a verse en pantalla una letra en inglés llena de insultos para
> una canción cristiana en español. El fallo es mío y es preciso: 'Amén'
> de Amén dura 188 segundos. En la base de letras hay un 'AmEN!' de
> Bring Me the Horizon que dura 189,5. Segundo y medio de diferencia."*

Ese texto **no fue escrito como descargo**. Es una anotación de trabajo,
hecha mientras se arreglaba el problema, en un registro con fecha y hora
verificable.

---

## 4. Qué se cambió para que no vuelva a pasar

1. **Se exige que el artista coincida.** Si no coincide, no se muestra
   nada. Se prefiere decir "no se encontró la letra" antes que mostrar
   la letra de otra canción.

2. **Se eliminó una segunda fuente de letras** (`lyrics.ovh`) que solo
   comparaba texto y no permitía verificar nada.

3. **Se descartó todo lo guardado con las reglas anteriores.** Las
   letras que ya estaban mal guardadas en el teléfono se borran solas y
   se vuelven a buscar con la regla nueva.

4. **Se agregaron tres pruebas automáticas**, incluida una que reproduce
   este caso exacto con los números reales, y que verifica que "AmEN!"
   de Bring Me the Horizon ya no puede volver a colarse.

Esas pruebas se pueden ejecutar y ver pasar:

```
flutter test test/utils/eleccion_letra_test.dart
```

Están en `test/utils/eleccion_letra_test.dart`, y el caso está
identificado con el nombre:

> *"el caso real de 'Amén': mismo largo, artista distinto, se descarta"*

---

## 5. Cómo verificar todo esto de forma independiente

El proyecto está en un repositorio público con todo su historial. No
hace falta confiar en este informe: se puede comprobar.

1. Abrir el repositorio del proyecto.
2. Buscar el registro `f77ca59` y leer su descripción y su fecha.
3. Ver los archivos `lib/utils/eleccion_letra.dart` y
   `test/utils/eleccion_letra_test.dart`, donde el caso está explicado y
   cubierto por pruebas.
4. Comprobar que la fecha del arreglo (16/09/2026) es anterior a este
   informe.

---

## 6. Conclusión

La aplicación mostró un texto ofensivo porque una base de datos pública
le devolvió la letra equivocada, por un parecido de título y de duración
de un segundo y medio.

No hubo intención. No hubo un texto cargado a mano. Hubo un error de
programación —identificado, explicado y corregido— en el mecanismo que
empareja canciones con letras.

Queda a disposición todo el código y el historial del proyecto para
cualquier verificación.
