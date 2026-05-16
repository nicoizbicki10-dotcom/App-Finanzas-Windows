# FinanzasAR — Instalación en Mac

Seguí estos pasos en orden. El proceso tarda entre 30 y 60 minutos dependiendo de tu conexión.

---

## Paso 1 — Instalar Xcode

Xcode es necesario para compilar la app en Mac y en iPhone.

1. Abrí la **App Store** en tu Mac
2. Buscá **Xcode** y hacé clic en **Obtener** (pesa ~10 GB, puede tardar)
3. Una vez instalado, abrilo una vez para aceptar los términos de licencia
4. Luego abrí la **Terminal** y ejecutá:
   ```
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```

---

## Paso 2 — Instalar Homebrew

Homebrew es el gestor de paquetes de Mac, lo usamos para instalar Flutter y otras herramientas.

1. Abrí la **Terminal** (buscala con `Cmd + Space` → escribí "Terminal")
2. Pegá este comando y presioná Enter:
   ```
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
3. Seguí las instrucciones en pantalla (te va a pedir tu contraseña)
4. Al terminar, si tu Mac tiene chip **Apple Silicon (M1/M2/M3/M4)**, ejecutá también:
   ```
   echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
   eval "$(/opt/homebrew/bin/brew shellenv)"
   ```

---

## Paso 3 — Instalar Flutter

En la Terminal:

```
brew install --cask flutter
```

Verificá que quedó bien instalado:

```
flutter --version
```

Tiene que mostrar algo como `Flutter 3.x.x`.

---

## Paso 4 — Instalar CocoaPods

CocoaPods maneja las dependencias nativas de iOS y macOS.

```
sudo gem install cocoapods
```

Si te da error de permisos, usá:

```
brew install cocoapods
```

---

## Paso 5 — Verificar la instalación

```
flutter doctor
```

Tenés que ver algo así:

```
[✓] Flutter
[✓] Xcode - develop for iOS and macOS
[✓] CocoaPods
[✓] Connected device
```

Si algún punto muestra una `X`, seguí las instrucciones que Flutter indica en pantalla.

---

## Paso 6 — Copiar el proyecto

Recibiste la carpeta `finanzas_ar`. Guardala en el lugar que prefieras, por ejemplo en tu carpeta de **Documentos**.

En la Terminal, navegá hasta ella:

```
cd ~/Documents/finanzas_ar
```

> Reemplazá la ruta si la guardaste en otro lugar. Podés arrastrar la carpeta desde el Finder a la Terminal para que escriba la ruta automáticamente.

---

## Paso 7 — Instalar dependencias

Dentro de la carpeta del proyecto:

```
flutter pub get
```

Luego instalá las dependencias nativas de macOS:

```
cd macos
pod install
cd ..
```

---

## Paso 8 — Ejecutar la app

### En la Mac (versión escritorio):

```
flutter run -d macos
```

### En un iPhone conectado:

1. Conectá el iPhone por cable USB
2. En el iPhone, cuando aparezca el mensaje **"¿Confiar en este ordenador?"** tocá **Confiar**
3. Ejecutá:
   ```
   flutter run -d ios
   ```

> La primera vez que corras en iPhone, Xcode puede pedirte que configures un **Apple ID** para firmar la app. Abrí Xcode → Settings → Accounts → agregá tu Apple ID (gratuito).

---

## Paso 9 — Generar una app instalable (opcional)

### Para Mac (archivo .app):

```
flutter build macos --release
```

El archivo queda en:
```
build/macos/Build/Products/Release/finanzas_ar.app
```

Podés arrastrar ese `.app` a la carpeta **Aplicaciones** de tu Mac.

---

## Problemas frecuentes

| Error | Solución |
|---|---|
| `flutter: command not found` | Cerrá y volvé a abrir la Terminal después de instalar Flutter |
| `CocoaPods not installed` | Ejecutá `brew install cocoapods` |
| `Xcode license not accepted` | Ejecutá `sudo xcodebuild -license accept` |
| `No connected device` | Verificá que el iPhone esté desbloqueado y hayas tocado "Confiar" |
| Error de firma en iPhone | Abrí Xcode, seleccioná el proyecto `ios/Runner.xcworkspace` y configurá tu Apple ID en Signing |
| `pod install` falla | Ejecutá `sudo gem install cocoapods` y volvé a intentar |

---

## Requisitos mínimos del sistema

| | Mínimo |
|---|---|
| Sistema operativo | macOS 13 (Ventura) o superior |
| Chip | Apple Silicon (M1/M2/M3/M4) o Intel |
| RAM | 8 GB |
| Espacio en disco | 20 GB libres (para Xcode + Flutter) |
| iPhone (opcional) | iOS 16 o superior |
