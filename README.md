# MaPeriT

Suite de peritación informática forense para sistemas Windows: adquiere las evidencias de un equipo, las analiza, permite revisarlas con un visor y responde preguntas concretas sobre ellas. No modifica las evidencias que recoge y trabaja sin conexión a Internet. Conforme a RFC 3227 y NIST SP 800-86.

**Software gratuito y de código abierto desarrollado por [Masoft.es](https://masoft.es)** · [Página de MaPeriT](https://masoft.es/maperit.html)

## Los cinco programas

| Programa | Versión | Qué hace |
|---|---|---|
| [MaPeriT.SW](MAPERIT_SW) | 1.7.5 | Adquisición forense en vivo de un Windows encendido, con informe pericial en HTML listo para presentar en un procedimiento judicial o una auditoría interna. |
| [MaPeriT.OF](MAPERIT_OF) | 1.1.2 | Adquisición forense offline sobre un disco montado o extraído, sin arrancar el sistema analizado. Mismas carpetas por fase que SW. |
| [MaPeriT.AN](MAPERIT_AN) | 1.2.1 | Análisis en profundidad de las evidencias de SW u OF: MFT, EVTX, bases de datos de navegadores, ShimCache/Amcache, USN Journal, detección de manipulación de fechas y línea temporal. |
| [MaPeriT.TN](MAPERIT_TN) | 1.1.2 | Visor forense de escritorio para navegar el proyecto completo: visores por tipo de fichero, detección de indicadores de compromiso, timeline consolidada y marcadores. |
| [MaPeriT.SC](MAPERIT_SC) | 1.0.1 | Asistente por pasos para que cualquier persona consulte, por patrones, lo ya analizado por AN. Genera un informe pericial y un resumen en lenguaje llano. |

## Flujo de trabajo

1. **Adquisición:** MaPeriT.SW si el equipo está encendido; MaPeriT.OF si está apagado o solo se dispone del disco.
2. **Análisis:** MaPeriT.AN sobre la carpeta de evidencias.
3. **Revisión:** MaPeriT.TN para el perito; MaPeriT.SC para quien necesita respuestas concretas sin interpretar ficheros técnicos.

## Requisitos

| Programa | Sistema | Permisos |
|---|---|---|
| SW | Windows 10, 11 o Server 2016+ (64 bits), el equipo analizado encendido | Administrador local del equipo analizado |
| OF | Windows 10, 11 o Server 2016+ (64 bits) en el equipo forense | Administrador local del equipo forense |
| AN | Windows 10, 11 o Server 2016+ (64 bits); 8 GB de RAM recomendados (mínimo 4 GB) | Administrador local |
| TN | Windows 10 u 11 (64 bits) o Server 2016+; pantalla mínima 1280×720 | Usuario normal |
| SC | Windows 10, 11 o Server 2016+ | Usuario normal |

Todos son scripts de Windows PowerShell 5.1: no necesitan instalación ni conexión a Internet. Para MaPeriT.OF se recomienda un bloqueador de escritura por hardware entre el disco y el equipo forense.

## Uso

Cada carpeta contiene el programa listo para ejecutar (`MaPeriT.XX.ps1`), su manual (`manual_maperit_xx.html`) y su ficha (`ficha_maperit_xx.html`). Ejemplo con MaPeriT.SW, en una consola de PowerShell como administrador:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\MaPeriT.SW.ps1 -CaseNumber "2026-001" -ExaminerName "Nombre del perito" -OutputPath "E:\Evidencias\2026-001"
```

Más ejemplos en [MAPERIT_SW/MaPeriT-Comandos.md](MAPERIT_SW/MaPeriT-Comandos.md) y en el manual de cada programa.

## Estructura del código

```
MAPERIT_SW/ MAPERIT_OF/ MAPERIT_AN/ MAPERIT_TN/ MAPERIT_SC/
├── MaPeriT.XX.ps1      programa compilado en un solo fichero (el que se ejecuta)
├── Build.ps1           une los módulos de src\ (y de ..\Common\) en MaPeriT.XX.ps1
├── src/                código fuente por módulos
├── manual_maperit_xx.html
└── ficha_maperit_xx.html
Common/                 módulos compartidos por SW, OF y AN (rutas y codificación HTML)
```

Para regenerar un programa tras modificar `src\`, ejecuta `.\Build.ps1` dentro de su carpeta. No edites `MaPeriT.XX.ps1` directamente.

## Componentes de terceros

`sqlite3.exe` (dominio público) y `winpmem_mini_x64.exe` (Apache 2.0) se incluyen sin modificar. Detalles en [TERCEROS.md](TERCEROS.md).

## Aviso legal

> MaPeriT solo debe ejecutarse en equipos y unidades de almacenamiento sobre los que el operador dispone de autorización explícita. Su uso en equipos de terceros sin autorización puede constituir un acceso no autorizado conforme al Código Penal.

**Limitaciones**
- No modifica ni borra los ficheros que recoge. Los hives del registro (en SW, los de usuarios sin sesión activa; en OF y AN, los de la evidencia) se consultan siempre sobre una copia de trabajo que se monta, se desmonta y se borra; el fichero original nunca se monta. Como toda adquisición en vivo, ejecutar MaPeriT.SW deja trazas propias en el equipo (registros de eventos, Prefetch de PowerShell, una instantánea VSS temporal).
- Las fechas de MaPeriT.AN están en UTC; las de MaPeriT.SW y las del USN Journal, en la hora local del equipo analizado. Los informes y la timeline indican la zona horaria.
- No realiza ninguna conexión de red ni envía datos fuera del equipo.
- La cadena de custodia protege la integridad de las evidencias tras la adquisición, pero no certifica la autenticidad del contenido original: eso corresponde al perito judicial.
- Los informes generados son documentos de trabajo. Su valor como prueba pericial depende de su presentación por un perito judicial habilitado.
- Se entrega «tal cual», sin garantía de ningún tipo.

## Licencia

Código publicado bajo licencia [MIT](LICENSE): puedes usarlo, modificarlo y redistribuirlo manteniendo el aviso de copyright. Los ejecutables de terceros conservan sus propias licencias ([TERCEROS.md](TERCEROS.md)).

© 2026 Masoft.es
