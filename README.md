<p align="center">
  <img src="docs/icono.png" width="160" alt="Ícono de TicoTV">
</p>

<h1 align="center">TicoTV</h1>

<p align="center">
  <b>TV en vivo, películas y series gratis y legales en español, en una app nativa para Mac.</b><br>
  Sin cuentas, sin suscripciones y sin rastreo.
</p>

<p align="center">
  Creado por <a href="https://github.com/Az0feifa"><b>Az0feifa</b></a> · Costa Rica 🇨🇷
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-SwiftUI-orange?logo=swift">
  <img alt="Versión" src="https://img.shields.io/badge/versi%C3%B3n-5.0-blue">
  <img alt="Licencia MIT" src="https://img.shields.io/badge/licencia-MIT-green">
</p>

<p align="center">
  <img src="docs/captura-inicio.jpg" width="900" alt="Pantalla de inicio de TicoTV">
</p>

---

## ¿Qué es TicoTV?

TicoTV junta en un solo lugar el contenido **gratuito y legal** que ya publican servicios como Pluto TV, Plex, Samsung TV Plus y las propias televisoras. Así no hay que saltar entre páginas web, apps y listas de canales.

La idea es simple: llegar a la casa, abrir una app y ver algo **en español** (latino, de España o subtitulado), con una experiencia parecida a Apple TV o Netflix, **sin pagar y sin recurrir a la piratería**.

### Lo que **no** es
- **No** es una app pirata. No incluye listas de servicios de pago, ni "IPTV premium", ni nada que rompa protecciones anticopia (DRM).
- **No** aloja ni redistribuye video. Cada transmisión viene directamente del servicio oficial que la publica, con sus anuncios incluidos. Así ese servicio sigue financiándose.
- **No** pide cuentas, correo ni tarjeta, y **no** recopila datos. Todo (favoritos, historial, perfiles) se guarda únicamente en su Mac.

---

## Fuentes de contenido

Todas son **gratuitas**, **legales** y se filtran para mostrar contenido **en español o subtitulado al español**.

| Fuente | Qué ofrece | Tipo |
|---|---|---|
| **Pluto TV** | ~190 canales en vivo con guía de programación, más películas y series a la carta | Oficial, gratis con anuncios |
| **Plex** | ~90 canales en vivo en español, además de películas, series y telenovelas a la carta | Oficial, gratis con anuncios (token anónimo, sin cuenta) |
| **Samsung TV Plus** | ~200 canales de España y canales latinos de EE. UU. | Oficial, gratis con anuncios |
| **Canales oficiales** | Señales que publican las propias televisoras: Repretel 4 y 6 🇨🇷, RTVE (24h, TVE Internacional, Star TVE, La 1) 🇪🇸, DW Español, France 24 Español, Canal 22 y TV UNAM 🇲🇽, Canal Sur, Televisión Canaria, entre otras | Emisoras públicas y privadas |
| **Canales abiertos** | Listas públicas de [iptv-org](https://github.com/iptv-org/iptv) por país (Costa Rica, México, España…) | Comunidad, solo señales abiertas |
| **Cine clásico** | Películas de dominio público o Creative Commons de [Internet Archive](https://archive.org) | Dominio público |

> El catálogo **se actualiza solo** cada 3 horas y cada vez que vuelve a la app. También puede actualizarlo con **⌘R**.
> La disponibilidad depende de cada servicio y de la región. Desde Costa Rica, algunos canales de Samsung TV Plus están bloqueados por región. TicoTV los detecta y los oculta automáticamente.

---

## Funciones

**Para ver**
- 🏠 **Inicio** con un título destacado y filas por categoría, al estilo de Apple TV.
- 🔎 **Búsqueda global** (⌘F) en canales, películas y series de todas las fuentes a la vez.
- 📺 **En vivo**, con selector de fuente, categorías y **guía de programación** (qué dan *ahora* y qué viene *después*).
- 🎬 **Películas** y 🎞️ **Series** con géneros, fichas, temporadas y episodios.

**Comodidad**
- ⏯️ **Seguir donde quedó**: cada película o episodio continúa en el mismo minuto, con una barra de progreso en el póster.
- ⏭️ **Siguiente episodio automático**: aviso con cuenta regresiva y botones *Ver ahora* o *Cancelar*.
- 🌙 **Temporizador para dormir**: apaga en 15–90 minutos o al terminar el episodio.
- 🗣️ **Idioma y subtítulos**: elige el audio y los subtítulos en español automáticamente cuando existen.
- 📡 **AirPlay**: envía el video a un televisor compatible.
- ⌨️ **Teclas multimedia** del teclado y **Centro de control** de macOS.
- ➕ **Mi lista** para ver después, ⭐ **Favoritos** y 💡 **"Porque vio…"** con recomendaciones.
- 👥 **Perfiles**: cada persona de la casa tiene su propio historial, Mi lista y "Seguir viendo".

**Atajos de teclado**

| Tecla | Acción |
|---|---|
| `espacio` | Pausa / reproduce |
| `f` | Pantalla completa |
| `esc` | Minimiza el reproductor / regresa |
| `←` `→` | Retrocede o adelanta 10 s |
| `n` | Siguiente episodio |
| `⌘F` | Buscar |
| `⌘R` | Actualizar catálogo |
| `⌘1`–`⌘7` | Ir a cada sección |

---

## Instalación

### Opción 1: instalador listo (recomendado)
1. Descargue **`TicoTV-5.0.dmg`** o **`TicoTV-5.0.pkg`** desde la sección [**Releases**](https://github.com/Az0feifa/TicoTV/releases).
2. **.dmg**: ábralo y arrastre TicoTV a *Aplicaciones*. **.pkg**: doble clic → Continuar → Instalar.
3. La primera vez, macOS puede decir que es de un *desarrollador no identificado*, porque la app no está firmada con un certificado pagado de Apple. En ese caso: **clic derecho sobre TicoTV → Abrir → Abrir**. Si no aparece la opción: *Configuración del Sistema → Privacidad y seguridad → Abrir igualmente*.

**Verifique que el archivo no fue alterado** (opcional):
```bash
shasum -a 256 -c SHA256SUMS   # debe decir OK
```

### Opción 2: compilar desde el código
Solo requiere las *Command Line Tools* de Apple, no hace falta Xcode completo:
```bash
xcode-select --install          # una sola vez
git clone https://github.com/Az0feifa/TicoTV.git
cd TicoTV
./build.sh                      # crea TicoTV.app
./build.sh --instaladores       # además genera .dmg, .pkg y SHA256SUMS en Instalador/
open TicoTV.app
```

**Requisitos:** macOS 14 Sonoma o superior (Apple Silicon o Intel) y conexión a internet.

---

## Seguridad y privacidad

TicoTV nació de un análisis de seguridad. Una app "gratuita" de IPTV para Android que circula en la región resultó estar ofuscada, con conexiones P2P/proxy ocultas y librerías de rastreo. TicoTV es la alternativa **limpia y transparente**: todo el código está aquí para que cualquiera lo revise.

| Protección | Qué significa para usted |
|---|---|
| **App Sandbox** | La app solo puede conectarse a internet como cliente. No puede leer sus archivos, ni usar la cámara o el micrófono, ni aceptar conexiones entrantes. |
| **Hardened Runtime** | Impide que otro programa inyecte código o librerías en TicoTV. |
| **Filtro de direcciones** | Se rechazan `file://`, `localhost`, las IPs de su red local (192.168.x, 10.x…), las credenciales en la URL y los esquemas raros. |
| **Redirecciones vigiladas** | Si un servidor intenta desviar a la app hacia su red local, la conexión se corta antes de salir. Esto se probó contra un servidor real. |
| **Servidores fijados por fuente** | Cada fuente solo acepta los dominios oficiales de su servicio (`*.pluto.tv`, `*.provider.plex.tv`, CDN de Samsung TV Plus…). Los tokens anónimos nunca se envían a terceros. |
| **Datos remotos validados** | IDs, duraciones, listas M3U y cabeceras se validan y se limitan en tamaño. Un dato malicioso no puede cerrar la app ni inyectar nada. |
| **Instalador .pkg sin scripts** | Solo copia la app a `/Applications`. Se publican sus sumas SHA-256. |
| **Cero telemetría** | No hay analíticas ni cuentas. Sus datos se quedan en `~/Library/Containers/com.az0feifa.ticotv`. |

El código pasó por varias revisiones con agentes de auditoría: SSRF, filtración de tokens, evasión de la fijación de servidores, inyección y posibles cierres provocados por datos remotos. Todos los hallazgos se corrigieron.

**Riesgo residual documentado:** el índice de Samsung TV Plus se obtiene a través de un servicio comunitario ([i.mjh.nz](https://i.mjh.nz)). Si ese servicio fuera comprometido, podría cambiar *qué video* se reproduce en un canal, pero **no** acceder a su red, a sus archivos ni a ninguna cuenta.

¿Encontró un problema de seguridad? Abra un [issue](https://github.com/Az0feifa/TicoTV/issues).

---

## Cómo está hecho

App nativa en **Swift + SwiftUI + AVKit**, sin dependencias externas: no usa CocoaPods, ni SPM, ni librerías de terceros.

```
TicoTV.swift          Núcleo: modelo de canal, descargas con límites, filtros de seguridad, parser M3U
Pluto.swift           Cliente oficial de Pluto TV (sesión, en vivo, a la carta, búsqueda, guía)
Providers.swift       Protocolo común para fuentes + reglas de seguridad (isSafeID, pinnedURL)
Prov_Plex.swift       Plex: canales en vivo y a la carta en español
Prov_FAST.swift       Samsung TV Plus (España + Latino)
Prov_Oficiales.swift  Señales oficiales de televisoras
Prov_Registry.swift   Lista de fuentes activas (agregar una fuente = un archivo + una línea aquí)
Model.swift           Estado de la app: navegación, catálogo, búsqueda, reproductor
Features.swift        Perfiles, progreso, temporizador, guía, AirPlay, teclas multimedia, auto-actualización
Components.swift      Tarjetas, filas, reproductor y controles
Views.swift           Pantallas
icon.swift            Genera el ícono a partir de assets/logo-original.png
build.sh              Compila, firma (ad-hoc + sandbox + hardened runtime) y crea instaladores
```

### Agregar una fuente nueva
1. Cree `Prov_MiFuente.swift` con un `enum MiFuenteProvider: StreamProvider`.
2. Cumpla las reglas de `Providers.swift`: solo HTTPS, `fetchCapped`, `pinnedURL` con los dominios oficiales, `isSafeID` en los IDs y **contenido gratuito, legal y en español**.
3. Agregue `MiFuenteProvider.self` a `Prov_Registry.swift`.

---

## Aviso legal

TicoTV es un proyecto personal, gratuito y sin fines de lucro. **No está afiliado** a Pluto TV (Paramount), Plex Inc., Samsung, Internet Archive, iptv-org ni a ninguna televisora. Todas las marcas pertenecen a sus dueños.

TicoTV no almacena, aloja ni redistribuye contenido: solo reproduce las transmisiones que cada servicio publica gratuitamente y de forma oficial, con sus anuncios. Si usted es titular de derechos de alguna señal y desea que se retire, abra un [issue](https://github.com/Az0feifa/TicoTV/issues) y se atenderá.

## Créditos

- Creado por **[Az0feifa](https://github.com/Az0feifa)**.
- Listas de canales abiertos: [iptv-org](https://github.com/iptv-org/iptv).
- Índice de canales FAST: [i.mjh.nz](https://i.mjh.nz) (Matt Huisman).
- Cine clásico: [Internet Archive](https://archive.org).

## Licencia

[MIT](LICENSE) © 2026 Az0feifa
