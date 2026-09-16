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
