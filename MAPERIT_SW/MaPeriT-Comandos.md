# MaPeriT.SW v1.7.5 — Comandos de Ejecución

## Requisito previo

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

---

## Adquisición básica

```powershell
.\MaPeriT.SW.ps1 -CaseNumber "2026-001" -ExaminerName "Juan Perez Garcia"
```

---

## Adquisición con salida a unidad externa y descripción

```powershell
.\MaPeriT.SW.ps1 -CaseNumber "CASO-2026-0457" `
    -ExaminerName "Ana Garcia Lopez" `
    -OutputPath "E:\Evidencias\CASO-0457" `
    -EvidenceDescription "Analisis del portatil HP del empleado para investigacion interna"
```

---

## Omitir fases y saltarse el volcado de RAM

```powershell
.\MaPeriT.SW.ps1 -CaseNumber "INC-789" `
    -ExaminerName "Carlos Martinez" `
    -SkipPhases "8,9" `
    -SkipRAM
```

---

## Firmar manifiesto con HMAC-SHA256

```powershell
.\MaPeriT.SW.ps1 -CaseNumber "JUD-2026-112" `
    -ExaminerName "Maria Fernandez Ruiz" `
    -OutputPath "F:\Peritajes\JUD-112" `
    -HMACKey "clave-secreta-peritaje-2026"
```

---

## Adquisición completa con ficheros grandes (PST/OST) y HMAC

```powershell
.\MaPeriT.SW.ps1 -CaseNumber "JUD-2026-112" `
    -ExaminerName "Maria Fernandez Ruiz" `
    -OutputPath "F:\Peritajes\JUD-112" `
    -CopyLargeFiles `
    -HMACKey "hmac-judicial-2026"
```

---

## Solo omitir Cloud Storage y USB (fases 8 y 9)

```powershell
.\MaPeriT.SW.ps1 -CaseNumber "CASO-123" `
    -ExaminerName "Ana Garcia" `
    -SkipPhases "8,9"
```

---

## Solo omitir RAM (sin winpmem o por tiempo)

```powershell
.\MaPeriT.SW.ps1 -CaseNumber "CASO-123" `
    -ExaminerName "Ana Garcia" `
    -SkipRAM
```

---

## Verificar integridad de una adquisición previa

```powershell
.\MaPeriT.SW.ps1 -VerifyPath "E:\Evidencias\MaPeriT_CASO-001_20260602_143022"
```

---

## Comprobar el entorno antes de una adquisición real (sin tocar nada)

```powershell
.\MaPeriT.SW.ps1 -DryRun
```

No requiere `-CaseNumber` ni `-ExaminerName`. No crea VSS, no monta hives, no copia nada:
solo comprueba privilegios, PowerShell, presencia de winpmem, perfiles de usuario y rutas
de artefactos clave.

---

## Verificar que la cadena de integridad funciona antes de ir al equipo objetivo

```powershell
.\MaPeriT.SW.ps1 -SelfTest
```

Prueba de humo (hash + copia + registro de custodia) contra un fichero sintético propio
de la herramienta. No toca el equipo objetivo. Código de salida 0 si todo OK, 1 si falla.

---

## Adquisición con minimización de datos (exclusión de rutas) y aislamiento de red documentado

```powershell
.\MaPeriT.SW.ps1 -CaseNumber "CASO-2026-0457" `
    -ExaminerName "Ana Garcia Lopez" `
    -ExcludePaths @("\Fotos Familiares\", "\Backups Personales\") `
    -NetworkIsolationCheck
```

---

## Adquisición judicial con modo estricto de cadena de custodia y límite de eventos ampliado

```powershell
.\MaPeriT.SW.ps1 -CaseNumber "JUD-2026-112" `
    -ExaminerName "Maria Fernandez Ruiz" `
    -OutputPath "F:\Peritajes\JUD-112" `
    -ChainOfCustodyStrictMode `
    -MaxEventsPerQuery 200000 `
    -HMACKey "hmac-judicial-2026"
```

`-ChainOfCustodyStrictMode` no aborta la adquisición en curso (perder datos volátiles de
fases posteriores por un solo hash fallido sería peor que el problema que soluciona);
marca el chequeo final de integridad como FALLIDO de forma muy visible en consola e
informe, y hace que el proceso termine con código de salida 2 en vez de 0, para que
scripts de automatización puedan detectarlo.

---

## Recompilar desde fuentes

```powershell
.\Build.ps1
```

---

## Referencia de parámetros

| Parámetro | Obligatorio | Descripción |
|-----------|-------------|-------------|
| `-CaseNumber` | Sí | Número de caso o expediente |
| `-ExaminerName` | Sí | Nombre del perito |
| `-OutputPath` | No | Directorio de salida (por defecto: `.\MaPeriT_<caso>_<timestamp>`) |
| `-EvidenceDescription` | No | Descripción del encargo pericial |
| `-SkipPhases` | No | Fases a omitir, separadas por comas o espacios, p. ej. `"8,9"` (texto desde v1.7.5) |
| `-SkipRAM` | No | Omite el volcado de RAM |
| `-CopyLargeFiles` | No | Copia ficheros >500 MB (PST/OST) |
| `-HMACKey` | No | Clave para firma HMAC-SHA256 del manifiesto |
| `-VerifyPath` | No | Modo verificación: comprueba integridad de adquisición previa |
| `-DryRun` | No | *(v1.7.1)* Preflight de solo lectura: comprueba el entorno sin tocar nada |
| `-SelfTest` | No | *(v1.7.1)* Prueba de humo de la cadena de integridad, sin tocar el equipo objetivo |
| `-ExcludePaths` | No | *(v1.7.1)* Array de fragmentos de ruta a excluir de la copia (minimización de datos) |
| `-NetworkIsolationCheck` | No | *(v1.7.1)* Documenta en el acta si el equipo tenía red activa al adquirir |
| `-ChainOfCustodyStrictMode` | No | *(v1.7.1)* Señala como FALLIDO el chequeo final si algún hash quedó inválido (no aborta) |
| `-MaxEventsPerQuery` | No | *(v1.7.1)* Sobrescribe el límite de eventos por consulta sin editar `Config.ps1` |

---

## Notas de la versión 1.7.5

Revisión completa con pruebas reales (16/11/2026). Cambios relevantes para el operador:

- **`-SkipPhases` es texto**: `-SkipPhases "8,9"` (o `"8 9"`). La forma `@(8,9)` fallaba al
  ejecutar el script con `powershell -File`.
- **`-VerifyPath` fiable**: antes daba siempre «integridad comprometida» porque el manifiesto
  incluía el propio registro de ejecución (`Logs\ActionLog.csv`). Ahora termina con código 0 si
  todo coincide y 1 si hay discrepancias.
- **Hives de usuarios sin sesión**: se monta una copia de trabajo de `NTUSER.DAT`; el fichero
  original del equipo analizado nunca se monta.
- **ShimCache completo y legible** (antes rutas corruptas y solo los primeros 4 KB).
- **Una sola anomalía ya no se pierde** (antes el informe podía decir «sin anomalías»).

## Notas de la versión 1.7.1

Auditoría de código completa (12/07/2026). Cambios relevantes para el operador:

- **Aviso crítico nuevo al finalizar**: si un hive de usuario montado temporalmente en
  `HKEY_USERS\MAPE_<usuario>` (Fase 4, para leer NTUSER.DAT/UsrClass.dat de usuarios sin
  sesión activa) no puede desmontarse tras 3 intentos, la consola mostrará un bloque en
  rojo `[!!!] AVISO CRITICO` con la clave exacta a desmontar manualmente
  (`reg unload <clave>`) antes de devolver o reiniciar el equipo analizado. Antes este
  fallo podía pasar desapercibido (solo quedaba como WARNING en el log).
- **Hashes inválidos ahora visibles**: si el cálculo de un hash SHA-256 falla tras copiar
  una evidencia (p. ej. un antivirus la elimina justo después), la entrada en
  `Logs\ChainOfCustody.csv` queda marcada con el prefijo `INVALIDO:` en vez de contener un
  texto de error sin marcar como si fuese un hash real. Esa evidencia ya no cuenta como
  "recopilada correctamente" en los contadores de fase.
- **Posible truncamiento de logs de eventos señalado**: si una consulta de un log de
  eventos (Security, Sysmon, PowerShell, etc.) alcanza el límite configurado
  (`MaxEventsPerQuery` u otros límites por fuente), ahora se registra un WARNING explícito
  "EVENTOS_POSIBLEMENTE_TRUNCADOS" en el log de ejecución para dejar constancia de que
  pueden existir más eventos no capturados.
- Ver el informe completo de la auditoría y el resto de correcciones en
  `manual_maperit_sw.html`, sección "Registro de cambios".
