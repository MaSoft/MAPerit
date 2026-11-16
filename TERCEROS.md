# Componentes de terceros

MaPeriT incluye dos ejecutables que no son de Masoft.es. Se redistribuyen sin modificar, bajo sus propias licencias.

| Archivo | Proyecto | Licencia | Origen |
|---|---|---|---|
| `MAPERIT_AN/Tools/sqlite3.exe` | SQLite (consola de comandos) | Dominio público | https://www.sqlite.org/copyright.html |
| `MAPERIT_SW/tools/winpmem_mini_x64.exe` | WinPmem (Velocidex) | Apache License 2.0 | https://github.com/Velocidex/WinPmem |

WinPmem es opcional: si no está en `MAPERIT_SW/tools/`, MaPeriT.SW omite el volcado de memoria RAM con un aviso.
