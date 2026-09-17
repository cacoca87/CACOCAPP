plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.caco.musicapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identidad permanente de la app en Android. Antes era
        // "com.example.musicapp", el valor de ejemplo que pone Flutter al
        // crear un proyecto: Google Play rechaza cualquier id que empiece
        // con "com.example", y una vez publicada la app este valor NO se
        // puede cambiar nunca mas. Se usa el mismo prefijo que ya usaban
        // el canal de notificaciones y el de efectos de audio.
        applicationId = "com.caco.musicapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // El APK de release se firma con la clave de DEPURACION, que
            // es la que Flutter deja por defecto. Para lo que hace falta
            // hoy -- pasar el APK al celular e instalarlo a mano --
            // funciona perfecto, y no obliga a guardar ninguna clave
            // secreta en el repositorio.
            //
            // Lo unico que hay que saber: esa clave vive en la
            // computadora donde se compila (~/.android/debug.keystore).
            // Si algun dia se compila en OTRA computadora, la firma va a
            // ser distinta y Android se va a negar a actualizar la app ya
            // instalada ("aplicacion no instalada"): hay que desinstalar
            // la vieja primero.
            //
            // Para publicar en Google Play SI haria falta una clave
            // propia, generada con `keytool` y guardada FUERA del
            // repositorio (en un `key.properties` ignorado por git).
            signingConfig = signingConfigs.getByName("debug")

            // COMO ACHICAR EL APK A LA MITAD (leer antes de compilar)
            //
            // Por defecto, `flutter build apk --release` pesa 62 MB, y
            // 22 de esos son codigo nativo para procesadores x86_64:
            // los de una computadora. NINGUN celular Android usa esa
            // arquitectura -- solo los emuladores que corren en una PC.
            // O sea que un tercio del archivo que hay que pasarle al
            // telefono es peso muerto que el telefono nunca va a poder
            // ejecutar.
            //
            // Para dejarlo afuera hay que compilar asi:
            //
            //     flutter build apk --release ^
            //         --target-platform android-arm,android-arm64
            //
            // Eso da UN solo APK de 41 MB (medido), que anda igual en
            // cualquier celular: quedan arm64-v8a (todos los de los
            // ultimos años) y armeabi-v7a (los viejos, de 32 bits).
            //
            // SE INTENTO dejarlo automatico desde aca, con
            // `ndk { abiFilters += ... }` en este mismo bloque. NO
            // FUNCIONA, y se comprobo compilando: `abiFilters` filtra
            // las librerias que arma el propio Android, pero las de
            // Flutter (libflutter.so y libapp.so, que son justo las
            // grandes) las agrega despues el plugin de Flutter por su
            // cuenta, y se cuelan igual. El APK salia de 62 MB con el
            // filtro puesto. Si alguien lo vuelve a intentar: ya se
            // probo, y el camino es la bandera de arriba.

            // Y SE PROBO TAMBIEN ACHICARLO CON R8 (minify + shrink).
            // Tampoco sirve, y se midio: el APK paso de 40,5 MB a
            // 40,6 --creció-- y compilar paso de 40 segundos a 242.
            //
            // El motivo es el mismo que arriba: lo que pesa en este APK
            // son las librerias nativas de Flutter (libflutter.so y
            // libapp.so), y R8 no las toca. Solo achica el codigo Java
            // y Kotlin, que aca es una pizca. Si alguien lo vuelve a
            // intentar: ya se probo, y lo unico que se gana es esperar
            // seis veces mas en cada compilacion.
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
