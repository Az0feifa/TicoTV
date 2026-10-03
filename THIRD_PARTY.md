# Third-Party Services and Sources

TicoTV interactúa con servicios, servidores, listas, metadatos y contenido proporcionados por terceros.

Este documento describe las principales dependencias externas observables en el código actual de TicoTV. **No pretende determinar ni interpretar los derechos de uso de cada servicio o contenido.**

---

## Alcance de la licencia de TicoTV

El código original de TicoTV se distribuye bajo **PolyForm Noncommercial License 1.0.0**.

La licencia se aplica únicamente al software y material sobre el que el licenciante tenga derechos. No debe interpretarse como si TicoTV concediera derechos pertenecientes a terceros.

En particular, TicoTV no puede conceder derechos sobre:

- transmisiones de televisión;
- películas, series o programas;
- imágenes y logotipos externos;
- marcas;
- APIs o infraestructura de terceros;
- bases de datos o metadatos pertenecientes a terceros.

Cada elemento puede estar sujeto a condiciones independientes.

---

# Pluto TV

TicoTV contiene una integración denominada PlutoClient.

El código:

- inicia una sesión contra infraestructura bajo dominios de Pluto TV;
- obtiene datos de sesión;
- consulta canales y categorías;
- consulta contenido bajo demanda;
- consulta programación;
- realiza búsquedas;
- obtiene URLs utilizadas para reproducción.

TicoTV valida que determinados servidores obtenidos dinámicamente pertenezcan al dominio pluto.tv.

TicoTV no opera esos servidores y no afirma afiliación, patrocinio o aprobación por parte de Pluto TV o Paramount.

El servicio y su contenido permanecen sujetos a las condiciones y derechos de sus respectivos titulares.

---

# Plex

TicoTV contiene una integración denominada PlexClient.

El código utiliza actualmente servicios bajo dominios como:

- clients.plex.tv
- epg.provider.plex.tv
- vod.provider.plex.tv

La aplicación:

- solicita un token para un usuario anónimo;
- consulta canales;
- consulta determinados catálogos;
- obtiene información de reproducción;
- excluye elementos que identifica como protegidos mediante DRM.

TicoTV no opera la infraestructura de Plex y no afirma afiliación, patrocinio o aprobación por parte de Plex.

El servicio y su contenido permanecen sujetos a las condiciones y derechos de sus respectivos titulares.

---

# Samsung TV Plus

TicoTV contiene un proveedor denominado SamsungTVPlusProvider.

## i.mjh.nz

El código consulta actualmente:

https://i.mjh.nz/SamsungTVPlus/.channels.json

Este recurso se utiliza para obtener datos de canales, como identificador, nombre, número, logo, descripción, categoría y presencia de una URL de licencia DRM.

TicoTV no opera i.mjh.nz.

## jmp2.uk

Para determinados canales, TicoTV solicita una URL con el formato:

https://jmp2.uk/stvp-<id>

La aplicación sigue la redirección y valida el host de destino antes de utilizarlo.

Entre los dominios admitidos actualmente por esa validación técnica se encuentran infraestructura bajo dominios asociados a Samsung TV Plus, CloudFront, Akamai, AWS MediaTailor, Amagi, Rakuten, Pluto TV, Wurl y NewID.

La inclusión de un dominio en esa lista es únicamente una decisión técnica de seguridad de red. **No constituye una afirmación sobre derechos de contenido, autorización comercial o afiliación.**

TicoTV no opera i.mjh.nz, jmp2.uk ni los CDN de destino y no afirma afiliación, patrocinio o aprobación por parte de Samsung.

---

# iptv-org

TicoTV obtiene playlists desde:

https://iptv-org.github.io/iptv

Actualmente consulta listas organizadas por país, idioma y categoría.

El proyecto iptv-org/iptv describe su repositorio como una colección de enlaces a canales públicamente disponibles.

TicoTV descarga las playlists M3U y utiliza URLs incluidas en ellas para solicitar transmisiones externas. TicoTV no aloja los videos enlazados por esas playlists.

El repositorio iptv-org/iptv mantiene su propia licencia para el material de su repositorio. Esa licencia no debe interpretarse automáticamente como una licencia sobre cada transmisión audiovisual enlazada.

Referencia:

https://github.com/iptv-org/iptv

---

# Internet Archive

TicoTV consulta servicios bajo archive.org.

El código utiliza:

- el buscador avanzado de Internet Archive;
- metadatos de elementos;
- archivos de video asociados a elementos encontrados.

TicoTV no opera Internet Archive.

Internet Archive contiene materiales con distintas situaciones de copyright y licenciamiento. La presencia de un elemento en Internet Archive no se presenta por sí sola como prueba de una licencia específica.

Cuando sea relevante, debe consultarse la información y licencia correspondiente al elemento concreto.

Referencia:

https://archive.org/

---

# Transmisiones configuradas directamente

El archivo Prov_Oficiales.swift contiene URLs de streams asociadas en el código a distintas emisoras o instituciones.

Actualmente aparecen referencias a fuentes como:

- Repretel;
- DW;
- France 24;
- RTVE;
- Canal Sur;
- Televisión Canaria;
- Canal Extremadura;
- Congreso de los Diputados de España;
- Canal 22;
- TV UNAM;
- Capital 21.

Las URLs apuntan a infraestructura externa. TicoTV no opera esos servidores ni almacena esas transmisiones.

La presencia de una URL en el código **no constituye por sí misma una afirmación sobre derechos de redistribución, retransmisión, explotación comercial o autorización del titular**.

---

# CDN e infraestructura de terceros

Durante la reproducción, TicoTV puede conectarse a redes de distribución utilizadas por los proveedores, incluidas infraestructuras bajo dominios relacionados con:

- Amazon CloudFront;
- AWS MediaTailor;
- Akamai;
- Amagi;
- Rakuten;
- Wurl.

La comunicación técnica con un CDN no significa que exista una relación contractual, asociación, patrocinio o aprobación entre TicoTV y el operador de ese CDN.

---

# Imágenes y metadatos

Los proveedores pueden devolver logotipos, pósteres, miniaturas, fondos, títulos, descripciones, guías de programación, categorías y otros metadatos.

Cuando TicoTV muestra esos elementos, normalmente se obtienen desde una fuente externa.

La licencia del código de TicoTV no debe interpretarse como una licencia sobre esos materiales.

---

# Marcas

Los nombres comerciales y marcas mencionados en el proyecto pertenecen a sus respectivos titulares.

La utilización de sus nombres dentro de TicoTV tiene como finalidad identificar las fuentes técnicas con las que interactúa la aplicación.

TicoTV no afirma afiliación, patrocinio o aprobación por parte de esos titulares.

---

# Cambios en servicios externos

Las integraciones de TicoTV dependen de servicios que el proyecto no controla.

Un proveedor puede cambiar URLs o APIs, exigir autenticación, aplicar restricciones geográficas, modificar sus condiciones, retirar contenido, implementar DRM, bloquear solicitudes o cerrar un servicio.

TicoTV no garantiza la disponibilidad permanente de ninguna fuente externa.

---

# Forks y modificaciones

Quien cree una versión modificada de TicoTV debe cumplir la licencia de TicoTV y revisar por separado las condiciones aplicables a cualquier servicio o fuente externa que decida utilizar.

La licencia de TicoTV no otorga automáticamente derechos sobre una fuente nueva añadida por un fork.

---

# Notificación sobre una integración

Si usted representa a un proveedor, titular de una marca o titular de derechos y desea informar sobre una integración concreta, puede abrir un issue:

https://github.com/Az0feifa/TicoTV/issues

Cuando sea posible, indique:

- la fuente afectada;
- la URL o integración correspondiente;
- una descripción del problema.

---

# Licencia del software

Consulte el archivo LICENSE del repositorio.

**PolyForm Noncommercial License 1.0.0**  
**SPDX: PolyForm-Noncommercial-1.0.0**

Este documento no modifica esa licencia ni concede derechos adicionales sobre materiales pertenecientes a terceros.
