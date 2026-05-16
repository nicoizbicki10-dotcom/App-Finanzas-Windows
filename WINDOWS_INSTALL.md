# FinanzasAR — Instalación en Windows

Seguí estos pasos en orden. El proceso tarda entre 20 y 40 minutos dependiendo de tu conexión.

---

## Paso 1 — Instalar Git

Git se usa para descargar el código del proyecto.

1. Entrá a https://git-scm.com/download/win
2. Descargá el instalador (64-bit)
3. Ejecutalo y hacé clic en **Next** en todas las pantallas (las opciones por defecto están bien)
4. Al terminar, abrí una ventana de **PowerShell** y verificá:
   ```
   git --version
   ```
   Tiene que mostrar algo como `git version 2.x.x`

---

## Paso 2 — Instalar Flutter SDK

1. Entrá a https://docs.flutter.dev/get-started/install/windows/desktop
2. Hacé clic en **Download Flutter SDK** y descargá el archivo `.zip`
3. Extraé el ZIP en `C:\flutter` (la ruta final tiene que ser `C:\flutter\bin\flutter.bat`)
4. Agregá Flutter al PATH del sistema:
   - Presioná `Win + S` y buscá **"Variables de entorno"**
   - Hacé clic en **"Editar las variables de entorno del sistema"**
   - En la ventana que se abre, hacé clic en **"Variables de entorno..."**
   - En la sección de arriba (**Variables de usuario**), seleccioná `Path` y hacé clic en **Editar**
   - Hacé clic en **Nuevo** y escribí `C:\flutter\bin`
   - Hacé clic en **Aceptar** en todas las ventanas
5. Cerrá y volvé a abrir PowerShell, luego verificá:
   ```
   flutter --version
   ```

---

## Paso 3 — Instalar Visual Studio 2022

Flutter necesita Visual Studio (no VS Code) para compilar la versión de Windows.

1. Entrá a https://visualstudio.microsoft.com/es/downloads/
2. Descargá **Visual Studio Community 2022** (es gratuito)
3. Ejecutá el instalador
4. En la pantalla de **Cargas de trabajo**, marcá:
   - ✅ **Desarrollo de escritorio con C++**
5. Hacé clic en **Instalar** (descarga ~7 GB, puede tardar)

---

## Paso 4 — Verificar la instalación

Abrí PowerShell y ejecutá:

```
flutter doctor
```

Tenés que ver algo así (los ticks verdes son los que importan):

```
[✓] Flutter
[✓] Windows Version
[✓] Visual Studio - develop Windows apps
[✓] Connected device
```

Si algún punto muestra una `X` con un mensaje de error, seguí las instrucciones que Flutter te da en pantalla.

---

## Paso 5 — Descargar el proyecto

En PowerShell, navegá a la carpeta donde querés guardar el proyecto y ejecutá:

```
git clone <URL-del-repositorio>
cd finanzas_ar
```

> Si no usás Git, también podés copiar la carpeta del proyecto directamente desde la Mac por USB o red local.

---

## Paso 6 — Instalar dependencias

Dentro de la carpeta del proyecto:

```
flutter pub get
```

Esto descarga todos los paquetes necesarios (tarda 1-2 minutos).

---

## Paso 7 — Ejecutar la app

```
flutter run -d windows
```

La primera vez tarda unos minutos en compilar. Las siguientes veces es mucho más rápido.

Para generar un **ejecutable instalable**:

```
flutter build windows --release
```

El ejecutable queda en:
```
build\windows\x64\runner\Release\finanzas_ar.exe
```

Podés copiar esa carpeta `Release` completa a cualquier PC con Windows y ejecutar la app directamente.

---

## Problemas frecuentes

| Error | Solución |
|---|---|
| `flutter: command not found` | Cerrá y volvé a abrir PowerShell después de agregar al PATH |
| `CMake not found` | Asegurate de haber instalado el workload "Desarrollo de escritorio con C++" en Visual Studio |
| `Unable to locate Visual Studio` | Ejecutá `flutter config --enable-windows-desktop` y volvé a intentar |
| La app no arranca | Ejecutá `flutter doctor` y seguí las instrucciones que aparezcan |

---

## Requisitos mínimos del sistema

| | Mínimo |
|---|---|
| Sistema operativo | Windows 10 (64-bit) o superior |
| RAM | 8 GB |
| Espacio en disco | 15 GB libres (para Flutter + Visual Studio) |
| Procesador | Intel Core i3 o equivalente |
