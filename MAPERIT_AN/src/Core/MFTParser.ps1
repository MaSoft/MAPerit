#region ============================================================
# MaPeriT.AN - PARSER MFT BINARIO (C# EMBEBIDO)
# Parsea el fichero $MFT extraido por MaPeriT.SW byte a byte.
# Lee atributos $STANDARD_INFORMATION y $FILE_NAME de cada File Record.
# ============================================================

$Script:MFTCSharp = @'
using System;
using System.IO;
using System.Collections.Generic;
using System.Text;

namespace MaPeriT
{
    public class MFTRecord
    {
        public long   RecordNumber;
        public bool   InUse;
        public bool   IsDirectory;
        public bool   IsDeleted;
        public string FileName;
        public int    FilenameNamespace;   // 0=POSIX 1=Win32 2=DOS 3=Win32&DOS
        public long   ParentRecordNumber;
        public long   FileSize;
        // $STANDARD_INFORMATION timestamps (manipulables por antiforensica)
        public DateTime SI_Created;
        public DateTime SI_Modified;
        public DateTime SI_MFTModified;
        public DateTime SI_Accessed;
        // $FILE_NAME timestamps (mas dificiles de falsificar)
        public DateTime FN_Created;
        public DateTime FN_Modified;
        public DateTime FN_MFTModified;
        public DateTime FN_Accessed;
        // Analisis
        public bool   IsTimestomped;
        public string TimestompReason;
        // Ruta completa (resuelta en segunda pasada)
        public string FullPath;
    }

    public class MFTParser
    {
        private const int RECORD_SIZE    = 1024;
        private const uint ATTR_SI       = 0x10;
        private const uint ATTR_FN       = 0x30;
        private const uint ATTR_END      = 0xFFFFFFFF;

        // ── Primera pasada: construir diccionario num→(nombre,padre) ──────────
        public static Dictionary<long, Tuple<string,long>> BuildPathIndex(string mftPath, Action<long,long> progress = null)
        {
            var index = new Dictionary<long, Tuple<string,long>>(500000);
            using (var fs = new FileStream(mftPath, FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 20))
            {
                long total = fs.Length / RECORD_SIZE;
                byte[] buf = new byte[RECORD_SIZE];
                long i = 0;
                while (true)
                {
                    int read = ReadFull(fs, buf, RECORD_SIZE);
                    if (read < RECORD_SIZE) break;
                    if (progress != null && i % 50000 == 0) progress(i, total);

                    if (buf[0] != 0x46 || buf[1] != 0x49 || buf[2] != 0x4C || buf[3] != 0x45) { i++; continue; }

                    ApplyUSA(buf);
                    // NOTA: no se descartan los registros "not in use" (borrados). Un
                    // fichero (borrado o no) dentro de una CARPETA borrada solo puede
                    // resolver su ruta completa si la carpeta borrada tambien esta en
                    // este indice - es precisamente el escenario de mayor valor
                    // forense (carpeta borrada + fichero borrado dentro). Antes se
                    // excluian aqui y la ruta resultante quedaba truncada a "[?]\nombre".

                    string fname = null;
                    int fnNs = 99;
                    long parent = 5; // root
                    ushort attrOff = LE16(buf, 0x14);
                    int pos = attrOff;
                    while (pos + 8 < RECORD_SIZE)
                    {
                        uint t = LE32(buf, pos);
                        if (t == ATTR_END) break;
                        uint len = LE32(buf, pos + 4);
                        if (len == 0 || pos + len > RECORD_SIZE) break;
                        if (t == ATTR_FN && buf[pos+8] == 0)
                        {
                            uint vLen = LE32(buf, pos+0x10);
                            ushort vOff = LE16(buf, pos+0x14);
                            int d = pos + vOff;
                            if (vLen >= 0x42 && d + 0x42 < RECORD_SIZE)
                            {
                                int ns = buf[d + 0x41];
                                if (fname == null || ns == 1 || ns == 3)
                                {
                                    parent = LE64(buf, d) & 0x0000FFFFFFFFFFFFL;
                                    fnNs   = ns;
                                    byte fnLen = buf[d + 0x40];
                                    int strStart = d + 0x42;
                                    if (strStart + fnLen * 2 <= RECORD_SIZE)
                                        fname = Encoding.Unicode.GetString(buf, strStart, fnLen * 2);
                                }
                            }
                        }
                        pos += (int)len;
                    }
                    if (fname != null)
                        index[i] = Tuple.Create(fname, parent);
                    i++;
                }
            }
            return index;
        }

        // ── Resolver ruta completa desde el indice ────────────────────────────
        public static string ResolvePath(long recordNum, Dictionary<long,Tuple<string,long>> index, int maxDepth = 32)
        {
            var parts = new List<string>();
            long cur = recordNum;
            for (int d = 0; d < maxDepth; d++)
            {
                if (!index.ContainsKey(cur)) { parts.Add("[?]"); break; }
                var entry = index[cur];
                parts.Add(entry.Item1);
                if (entry.Item2 == 5 || entry.Item2 == cur) break; // raiz o ciclo
                cur = entry.Item2;
            }
            parts.Reverse();
            return string.Join("\\", parts);
        }

        // ── Segunda pasada: parseo completo ───────────────────────────────────
        public static IEnumerable<MFTRecord> ParseAll(
            string mftPath,
            Dictionary<long,Tuple<string,long>> pathIndex,
            long maxRecords,
            int timestompThresholdSec,
            Action<long,long> progress)
        {
            using (var fs = new FileStream(mftPath, FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 20))
            {
                long total = fs.Length / RECORD_SIZE;
                if (maxRecords > 0) total = Math.Min(total, maxRecords);
                byte[] buf = new byte[RECORD_SIZE];
                long i = 0;
                while (i < total)
                {
                    int read = ReadFull(fs, buf, RECORD_SIZE);
                    if (read < RECORD_SIZE) break;
                    if (progress != null && i % 25000 == 0) progress(i, total);

                    var r = ParseRecord(buf, i, timestompThresholdSec);
                    if (r != null)
                    {
                        r.FullPath = ResolvePath(i, pathIndex);
                        if (r.IsDeleted) r.FullPath = "[BORRADO] " + r.FullPath;
                        yield return r;
                    }
                    i++;
                }
            }
        }

        // ── Parsear un record de 1024 bytes ───────────────────────────────────
        private static MFTRecord ParseRecord(byte[] raw, long idx, int threshSec)
        {
            if (raw[0] != 0x46 || raw[1] != 0x49 || raw[2] != 0x4C || raw[3] != 0x45)
                return null;

            byte[] buf = (byte[])raw.Clone();
            ApplyUSA(buf);

            ushort flags = LE16(buf, 0x16);
            var r = new MFTRecord
            {
                RecordNumber = idx,
                InUse        = (flags & 1) != 0,
                IsDirectory  = (flags & 2) != 0,
                IsDeleted    = (flags & 1) == 0
            };

            bool hasSI = false, hasFN = false;
            ushort attrOff = LE16(buf, 0x14);
            int pos = attrOff;

            while (pos + 8 < RECORD_SIZE)
            {
                uint t   = LE32(buf, pos);
                if (t == ATTR_END) break;
                uint len = LE32(buf, pos + 4);
                if (len == 0 || pos + len > RECORD_SIZE) break;

                bool nonRes = buf[pos + 8] != 0;

                if (!nonRes)
                {
                    uint vLen = LE32(buf, pos + 0x10);
                    ushort vOff = LE16(buf, pos + 0x14);
                    int d = pos + vOff;

                    if (t == ATTR_SI && vLen >= 48 && d + 48 <= RECORD_SIZE)
                    {
                        r.SI_Created     = FT(buf, d + 0);
                        r.SI_Modified    = FT(buf, d + 8);
                        r.SI_MFTModified = FT(buf, d + 16);
                        r.SI_Accessed    = FT(buf, d + 24);
                        hasSI = true;
                    }
                    else if (t == ATTR_FN && vLen >= 0x42 && d + 0x42 <= RECORD_SIZE)
                    {
                        int ns = buf[d + 0x41];
                        if (!hasFN || ns == 1 || ns == 3)
                        {
                            r.ParentRecordNumber = LE64(buf, d) & 0x0000FFFFFFFFFFFFL;
                            r.FN_Created         = FT(buf, d + 0x08);
                            r.FN_Modified        = FT(buf, d + 0x10);
                            r.FN_MFTModified     = FT(buf, d + 0x18);
                            r.FN_Accessed        = FT(buf, d + 0x20);
                            r.FileSize           = LE64(buf, d + 0x30);
                            r.FilenameNamespace  = ns;
                            byte fnLen = buf[d + 0x40];
                            int strStart = d + 0x42;
                            if (fnLen > 0 && strStart + fnLen * 2 <= RECORD_SIZE)
                                r.FileName = Encoding.Unicode.GetString(buf, strStart, fnLen * 2);
                            hasFN = true;
                        }
                    }
                }
                pos += (int)len;
            }

            if (!hasFN) return null;

            // Timestomping detection — solo indicadores fiables (SI < FN)
            // Se elimina el check de precision sub-segundo: demasiados falsos positivos
            // en ficheros de sistema instalados con timestamps redondeados.
            if (hasSI && r.SI_Created != DateTime.MinValue && r.FN_Created != DateTime.MinValue)
            {
                var reasons = new List<string>();
                var ts = TimeSpan.FromSeconds(threshSec);

                // Indicador primario: SI anterior a FN (imposible sin manipulacion)
                if (r.SI_Created  < r.FN_Created  - ts) reasons.Add("SI_Created < FN_Created");
                if (r.SI_Modified < r.FN_Modified - ts) reasons.Add("SI_Modified < FN_Modified");

                // Indicador logico: fichero creado despues de modificado (imposible)
                if (r.SI_Created > r.SI_Modified + TimeSpan.FromSeconds(60) &&
                    r.SI_Modified > DateTime.MinValue)
                    reasons.Add("SI_Created > SI_Modified+60s (imposible)");

                // Sub-segundo SOLO si la diferencia SI<FN es ademas de mas de 1 hora
                // (descartamos ruido de instalacion de Windows)
                if (reasons.Count == 0)
                {
                    bool siNoSubSec = r.SI_Created.Ticks  % 10000000 == 0 &&
                                      r.SI_Modified.Ticks % 10000000 == 0 &&
                                      r.SI_MFTModified.Ticks % 10000000 == 0;
                    bool fnHasSubSec= r.FN_Created.Ticks  % 10000000 != 0 ||
                                      r.FN_Modified.Ticks % 10000000 != 0;
                    bool bigDiff    = Math.Abs((r.SI_Created - r.FN_Created).TotalHours) > 1.0 ||
                                      Math.Abs((r.SI_Modified - r.FN_Modified).TotalHours) > 1.0;
                    if (siNoSubSec && fnHasSubSec && bigDiff)
                        reasons.Add("Precision SI=0 + diferencia >1h con FN");
                }

                if (reasons.Count > 0)
                {
                    r.IsTimestomped   = true;
                    r.TimestompReason = string.Join("; ", reasons);
                }
            }
            return r;
        }

        // ── USA Fixup ─────────────────────────────────────────────────────────
        private static void ApplyUSA(byte[] buf)
        {
            ushort usaOff  = LE16(buf, 4);
            ushort usaSize = LE16(buf, 6);
            if (usaOff == 0 || usaSize < 2 || usaOff + usaSize * 2 > RECORD_SIZE) return;
            for (int i = 1; i < usaSize; i++)
            {
                int sectorEnd = i * 512 - 2;
                int usaEntry  = usaOff + i * 2;
                if (sectorEnd + 2 > RECORD_SIZE || usaEntry + 2 > RECORD_SIZE) break;
                buf[sectorEnd]     = buf[usaEntry];
                buf[sectorEnd + 1] = buf[usaEntry + 1];
            }
        }

        // ── Helpers ───────────────────────────────────────────────────────────
        private static ushort LE16(byte[] b, int o) => (ushort)(b[o] | b[o+1] << 8);
        private static uint   LE32(byte[] b, int o) => (uint)(b[o] | b[o+1]<<8 | b[o+2]<<16 | b[o+3]<<24);
        private static long   LE64(byte[] b, int o) => (long)((ulong)b[o] | (ulong)b[o+1]<<8 | (ulong)b[o+2]<<16 |
                                                               (ulong)b[o+3]<<24 | (ulong)b[o+4]<<32 | (ulong)b[o+5]<<40 |
                                                               (ulong)b[o+6]<<48 | (ulong)b[o+7]<<56);
        private static DateTime FT(byte[] b, int o)
        {
            long ft = LE64(b, o);
            if (ft <= 0) return DateTime.MinValue;
            try { return DateTime.FromFileTimeUtc(ft); } catch { return DateTime.MinValue; }
        }
        private static int ReadFull(Stream s, byte[] buf, int size)
        {
            int total = 0;
            while (total < size)
            {
                int r = s.Read(buf, total, size - total);
                if (r == 0) break;
                total += r;
            }
            return total;
        }
    }
}
'@

function Initialize-MFTParser {
    try {
        Add-Type -TypeDefinition $Script:MFTCSharp -Language CSharp -ErrorAction Stop
        Write-ANLog -Action "MFTPARSER_CARGADO" -Target "MaPeriT.MFTParser" -Result "OK"
        return $true
    } catch {
        if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*MaPeriT*") { return $true }
        Write-ANLog -Action "MFTPARSER_ERROR" -Target $_.Exception.Message -Result "ERROR"
        return $false
    }
}

function Invoke-MFTAnalysis {
    param(
        [string]$MFTPath,
        [string]$OutputPath,
        [long]$MaxRecords = 0
    )

    Write-ANSection "ANALISIS MFT - MASTER FILE TABLE"
    $mftOut = Join-Path $OutputPath $Script:AN_Dirs.MFT

    if (-not (Test-Path $MFTPath)) {
        Write-ANLog -Phase "MFT" -Action "MFT_NO_ENCONTRADO" -Target $MFTPath -Result "ERROR"
        return
    }

    $mftSize = [math]::Round((Get-Item $MFTPath).Length / 1MB, 1)
    $estRecords = [math]::Floor((Get-Item $MFTPath).Length / 1024)
    Write-ANLog -Phase "MFT" -Action "MFT_ENCONTRADO" -Target "$mftSize MB / ~$estRecords registros estimados" -Result "OK"

    # ── Fase 1: construir indice de rutas ──────────────────────────────
    Write-Host "  [*] Fase 1/2: construyendo indice de rutas..." -ForegroundColor Yellow
    $progressCb = [Action[long,long]]{ param($c,$t) Write-ANProgress "Indexando" $c $t }

    try {
        $pathIndex = [MaPeriT.MFTParser]::BuildPathIndex($MFTPath, $progressCb)
        Write-Host ""
        Write-ANLog -Phase "MFT" -Action "INDICE_CONSTRUIDO" -Target "$($pathIndex.Count) entradas" -Result "OK"
    } catch {
        Write-Host ""
        Write-ANLog -Phase "MFT" -Action "INDICE_ERROR" -Target $_.Exception.Message -Result "ERROR"
        return
    }

    # ── Fase 2: parseo completo ────────────────────────────────────────
    Write-Host "  [*] Fase 2/2: parseo completo de atributos y timestamps..." -ForegroundColor Yellow
    $progressCb2 = [Action[long,long]]{ param($c,$t) Write-ANProgress "Parseando" $c $t }

    $allRecords    = [System.Collections.Generic.List[object]]::new()
    $timestomped   = [System.Collections.Generic.List[object]]::new()
    $deleted       = [System.Collections.Generic.List[object]]::new()

    try {
        $records = [MaPeriT.MFTParser]::ParseAll($MFTPath, $pathIndex, $MaxRecords, $Script:TimestompThreshold, $progressCb2)
        foreach ($r in $records) {
            $obj = [PSCustomObject]@{
                RecordNum       = $r.RecordNumber
                Estado          = if ($r.IsDeleted) {"BORRADO"} elseif ($r.IsDirectory) {"DIRECTORIO"} else {"FICHERO"}
                NombreFichero   = $r.FileName
                RutaCompleta    = $r.FullPath
                TamanoBytes     = $r.FileSize
                Namespace       = $Script:MFT_Namespaces[$r.FilenameNamespace]
                SI_Creado_UTC   = if ($r.SI_Created -gt [datetime]::MinValue) {$r.SI_Created.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                SI_Modificado_UTC = if ($r.SI_Modified -gt [datetime]::MinValue) {$r.SI_Modified.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                SI_MFT_UTC      = if ($r.SI_MFTModified -gt [datetime]::MinValue) {$r.SI_MFTModified.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                SI_Acceso_UTC   = if ($r.SI_Accessed -gt [datetime]::MinValue) {$r.SI_Accessed.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                FN_Creado_UTC   = if ($r.FN_Created -gt [datetime]::MinValue) {$r.FN_Created.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                FN_Modificado_UTC = if ($r.FN_Modified -gt [datetime]::MinValue) {$r.FN_Modified.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                FN_MFT_UTC      = if ($r.FN_MFTModified -gt [datetime]::MinValue) {$r.FN_MFTModified.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                FN_Acceso_UTC   = if ($r.FN_Accessed -gt [datetime]::MinValue) {$r.FN_Accessed.ToString("yyyy-MM-dd HH:mm:ss.fffffff")} else {""}
                Timestomping    = $r.IsTimestomped
                RazonTimestomp  = $r.TimestompReason
            }
            $allRecords.Add($obj)
            if ($r.IsTimestomped) { $timestomped.Add($obj) }
            if ($r.IsDeleted -and $r.FileName -notlike "`$*") { $deleted.Add($obj) }
        }
        Write-Host ""
    } catch {
        Write-Host ""
        Write-ANLog -Phase "MFT" -Action "PARSEO_ERROR" -Target $_.Exception.Message -Result "ERROR"
        return
    }

    # ── Exportar resultados ────────────────────────────────────────────
    Write-ANLog -Phase "MFT" -Action "PARSEO_COMPLETO" -Target "$($allRecords.Count) registros validos" -Result "OK"
    $Script:ANSession.MFTRecords    = $allRecords.Count
    $Script:ANSession.MFTTimestomped= $timestomped.Count
    $Script:ANSession.MFTDeleted    = $deleted.Count

    # MFT completo (puede ser grande — chunked por si acaso)
    $allPath = Join-Path $mftOut "MFT_Completo.csv"
    Export-ANData -Data $allRecords.ToArray() -Path $allPath -Description "MFT completo"

    $tsPath = Join-Path $mftOut "MFT_Timestomping.csv"
    Export-ANData -Data $timestomped.ToArray() -Path $tsPath -Description "Ficheros con posible timestomping"

    $delPath = Join-Path $mftOut "MFT_Borrados.csv"
    Export-ANData -Data $deleted.ToArray() -Path $delPath -Description "Ficheros borrados"

    Write-ANLog -Phase "MFT" -Action "RESUMEN" -Target "Total=$($allRecords.Count) Timestomped=$($timestomped.Count) Borrados=$($deleted.Count)" -Result "OK"
}
