# Política de seguridad

## Reportar una vulnerabilidad

Si encuentra un problema de seguridad en TicoTV, **no abra un issue público**.

Repórtelo de forma privada desde la pestaña **Security → Report a vulnerability** de este repositorio:
<https://github.com/Az0feifa/TicoTV/security/advisories/new>

Incluya, si puede:
- la versión de TicoTV y de macOS;
- los pasos para reproducir el problema;
- el impacto que observa (por ejemplo: acceso a la red local, filtración de datos, cierre de la app).

Recibirá respuesta en cuanto sea posible. Una vez corregido, se publicará una nueva versión y se reconocerá su aporte si así lo desea.

## Versiones con soporte

Solo la versión más reciente publicada en [Releases](https://github.com/Az0feifa/TicoTV/releases/latest) recibe correcciones de seguridad.

## Alcance

Dentro del alcance: el código de este repositorio y los instaladores publicados en Releases.

Fuera del alcance: los servicios de terceros que TicoTV consulta (Pluto TV, Plex, Samsung TV Plus, iptv-org, Internet Archive y televisoras). Los problemas de esos servicios deben reportarse a sus responsables.

## Verificar las descargas

Cada versión publica el archivo `SHA256SUMS`. Compare los instaladores antes de abrirlos:

```bash
cd ~/Downloads
shasum -a 256 -c SHA256SUMS --ignore-missing
```
