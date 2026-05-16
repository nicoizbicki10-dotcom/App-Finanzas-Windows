# FinanzasAR — Guía de Instalación y Configuración

## Requisitos Previos

### 1. Instalar Flutter
```bash
# macOS (con Homebrew)
brew install flutter

# O descargar desde https://flutter.dev/docs/get-started/install
```

Verificar instalación:
```bash
flutter doctor
```

### 2. Plataformas soportadas
- **iOS**: Requiere Xcode (solo macOS)
- **Windows**: Requiere Visual Studio con "Desktop development with C++"
- **macOS**: Requiere Xcode

---

## Configuración del Proyecto

### 1. Clonar o abrir el proyecto
```bash
cd "Proyectos Claude Code/finanzas_ar"
```

### 2. Instalar dependencias
```bash
flutter pub get
```

### 3. Obtener API Key de Finnhub (GRATUITO)

1. Ir a **https://finnhub.io** → Registrarse gratis
2. Copiar tu API key del dashboard
3. Editar `lib/core/constants/api_constants.dart`:
   ```dart
   static const String finnhubApiKey = 'TU_API_KEY_AQUI';
   ```

> **Nota**: Las APIs de dolarapi.com y CoinGecko son completamente gratuitas y no requieren registro.

---

## Ejecutar la App

### iOS (Simulator)
```bash
open -a Simulator
flutter run
```

### iOS (Device físico)
```bash
flutter run --release
```

### Windows
```bash
flutter run -d windows
```

### Modo debug con hot reload
```bash
flutter run
# Presionar 'r' para hot reload, 'R' para hot restart
```

---

## Estructura del Proyecto

```
lib/
├── main.dart                    # Punto de entrada
├── app.dart                     # MaterialApp con tema y router
├── core/
│   ├── constants/               # Colores, espaciado, endpoints
│   ├── theme/                   # Tema oscuro completo
│   ├── router/                  # Navegación con go_router
│   ├── network/                 # Cliente Dio para APIs
│   ├── storage/                 # Hive (almacenamiento local)
│   ├── utils/                   # Formatters de moneda y fecha
│   └── widgets/                 # Widgets reutilizables
└── features/
    ├── dashboard/               # Resumen Completo
    ├── gastos/                  # Gastos Fijos + Variables
    ├── ingresos/                # Ingresos Fijos + Variables
    ├── inversiones/             # Inmuebles, Acciones, Cripto, Liquidez, Otras
    ├── objetivos/               # Objetivos financieros
    ├── rentabilidad/            # Ranking de mayor rentabilidad
    └── market_data/             # APIs en tiempo real (Dólar, Cripto, Acciones)
```

---

## APIs Utilizadas

| API | URL | Límite gratuito |
|-----|-----|-----------------|
| DolarAPI | https://dolarapi.com/v1 | Sin límite documentado |
| CoinGecko | https://api.coingecko.com/api/v3 | ~30 req/min |
| Finnhub | https://finnhub.io/api/v1 | 60 req/min |

---

## Funcionalidades

### Dashboard (Resumen Completo)
- Balance del mes (Ingresos - Gastos)
- Tipo de cambio en tiempo real (Oficial, Blue, MEP, CCL, Cripto)
- Flujo de caja: gráfico de barras últimos 6 meses
- Distribución del patrimonio: gráfico de torta

### Gastos
- Registro de gastos fijos y variables
- Categorización automática con emoji
- Gráfico de torta por categoría
- Swipe para eliminar
- Soporte para gastos recurrentes

### Ingresos
- Registro de ingresos fijos y variables
- Gráfico de línea de evolución (12 meses)
- Categorías: salario, freelance, alquiler, dividendos, etc.

### Inversiones
- **Inmuebles**: valoración en USD, alquiler mensual
- **Acciones**: cotizaciones en tiempo real via Finnhub
- **Criptomonedas**: precios via CoinGecko, imagen automática
- **Liquidez**: cuentas bancarias, plazos fijos, efectivo
- **Otras**: cualquier activo con valoración manual

### Objetivos
- Progreso visual con barra animada
- Mini gráfico de evolución histórica
- Cálculo de ahorro mensual requerido
- Proyección a fecha meta

### Rentabilidad
- Ranking de todas las inversiones por ROI
- Podio Top 3 con medallas
- Gráfico de barras horizontal comparativo
- Datos reales de mercado para acciones y cripto

---

## Personalización

### Cambiar colores
Editar `lib/core/constants/app_colors.dart`

### Agregar categorías de gastos/ingresos
Editar los enums en:
- `lib/features/gastos/domain/gasto.dart`
- `lib/features/ingresos/domain/ingreso.dart`

### Cambiar intervalo de actualización
Editar `lib/core/constants/api_constants.dart`:
```dart
static const int dolarRefreshInterval = 300;   // segundos
static const int cryptoRefreshInterval = 60;
static const int stockRefreshInterval = 30;
```

---

## Publicar en App Store / Microsoft Store

### iOS — App Store
1. Tener cuenta de Apple Developer ($99/año)
2. Configurar Bundle ID en Xcode
3. `flutter build ipa`
4. Subir con Transporter o Xcode Organizer

### Windows — Microsoft Store
1. Tener cuenta de Partner Center
2. `flutter build windows --release`
3. Empaquetar con MSIX: `flutter pub add msix` → `flutter pub run msix:create`
4. Subir el .msix al Partner Center
