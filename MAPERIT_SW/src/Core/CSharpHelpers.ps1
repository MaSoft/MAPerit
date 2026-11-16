#region ============================================================
# MaPeriT.SW - HELPERS C# EMBEBIDOS
# Acceso raw NTFS: MFT, USN Journal via P/Invoke
# ============================================================

function Initialize-CSharpHelpers {
    $csharpCode = @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.ComponentModel;

namespace MaPeriT
{
    public class NativeMethods
    {
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr CreateFile(
            string lpFileName,
            uint dwDesiredAccess,
            uint dwShareMode,
            IntPtr lpSecurityAttributes,
            uint dwCreationDisposition,
            uint dwFlagsAndAttributes,
            IntPtr hTemplateFile);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool ReadFile(
            IntPtr hFile,
            byte[] lpBuffer,
            uint nNumberOfBytesToRead,
            out uint lpNumberOfBytesRead,
            IntPtr lpOverlapped);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetFilePointerEx(
            IntPtr hFile,
            long liDistanceToMove,
            out long lpNewFilePointer,
            uint dwMoveMethod);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool DeviceIoControl(
            IntPtr hDevice,
            uint dwIoControlCode,
            IntPtr lpInBuffer,
            uint nInBufferSize,
            IntPtr lpOutBuffer,
            uint nOutBufferSize,
            out uint lpBytesReturned,
            IntPtr lpOverlapped);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(IntPtr hObject);

        public const uint GENERIC_READ = 0x80000000;
        public const uint FILE_SHARE_READ = 0x00000001;
        public const uint FILE_SHARE_WRITE = 0x00000002;
        public const uint OPEN_EXISTING = 3;
        public const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;
        public const uint FSCTL_GET_NTFS_VOLUME_DATA = 0x00090064;
        public const uint FILE_BEGIN = 0;
        public static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct NTFS_VOLUME_DATA_BUFFER
    {
        public long VolumeSerialNumber;
        public long NumberSectors;
        public long TotalClusters;
        public long FreeClusters;
        public long TotalReserved;
        public uint BytesPerSector;
        public uint BytesPerCluster;
        public uint BytesPerFileRecordSegment;
        public uint ClustersPerFileRecordSegment;
        public long MftValidDataLength;
        public long MftStartLcn;
        public long Mft2StartLcn;
        public long MftZoneStart;
        public long MftZoneEnd;
    }

    public class RawDiskReader : IDisposable
    {
        private IntPtr _volumeHandle = NativeMethods.INVALID_HANDLE_VALUE;
        private string _volumePath;
        private bool _disposed = false;

        public NTFS_VOLUME_DATA_BUFFER VolumeData { get; private set; }
        public bool IsOpen { get; private set; }
        public string LastError { get; private set; }

        public bool OpenVolume(string driveLetter)
        {
            _volumePath = @"\\.\" + driveLetter.TrimEnd('\\');
            _volumeHandle = NativeMethods.CreateFile(
                _volumePath,
                NativeMethods.GENERIC_READ,
                NativeMethods.FILE_SHARE_READ | NativeMethods.FILE_SHARE_WRITE,
                IntPtr.Zero,
                NativeMethods.OPEN_EXISTING,
                NativeMethods.FILE_FLAG_BACKUP_SEMANTICS,
                IntPtr.Zero);

            if (_volumeHandle == NativeMethods.INVALID_HANDLE_VALUE)
            {
                LastError = "CreateFile failed: " + new Win32Exception(Marshal.GetLastWin32Error()).Message;
                IsOpen = false;
                return false;
            }

            IsOpen = true;
            return ReadVolumeData();
        }

        private bool ReadVolumeData()
        {
            int size = Marshal.SizeOf(typeof(NTFS_VOLUME_DATA_BUFFER));
            IntPtr buffer = Marshal.AllocHGlobal(size);

            try
            {
                uint bytesReturned;
                bool result = NativeMethods.DeviceIoControl(
                    _volumeHandle,
                    NativeMethods.FSCTL_GET_NTFS_VOLUME_DATA,
                    IntPtr.Zero, 0,
                    buffer, (uint)size,
                    out bytesReturned,
                    IntPtr.Zero);

                if (!result)
                {
                    LastError = "FSCTL_GET_NTFS_VOLUME_DATA failed: " + new Win32Exception(Marshal.GetLastWin32Error()).Message;
                    return false;
                }

                VolumeData = (NTFS_VOLUME_DATA_BUFFER)Marshal.PtrToStructure(buffer, typeof(NTFS_VOLUME_DATA_BUFFER));
                return true;
            }
            finally
            {
                Marshal.FreeHGlobal(buffer);
            }
        }

        public bool ExtractMFT(string outputPath, Action<long, long> progressCallback = null)
        {
            if (!IsOpen)
            {
                LastError = "Volume not open";
                return false;
            }

            long mftOffset = VolumeData.MftStartLcn * VolumeData.BytesPerCluster;
            long mftSize = VolumeData.MftValidDataLength;

            if (mftSize <= 0)
            {
                LastError = "MFT size is zero or invalid";
                return false;
            }

            long newPos;
            if (!NativeMethods.SetFilePointerEx(_volumeHandle, mftOffset, out newPos, NativeMethods.FILE_BEGIN))
            {
                LastError = "SetFilePointerEx failed: " + new Win32Exception(Marshal.GetLastWin32Error()).Message;
                return false;
            }

            int bufferSize = (int)VolumeData.BytesPerCluster * 64;
            if (bufferSize <= 0 || bufferSize > 4 * 1024 * 1024)
                bufferSize = 1024 * 1024;

            byte[] buffer = new byte[bufferSize];
            long totalRead = 0;

            try
            {
                using (FileStream outStream = new FileStream(outputPath, FileMode.Create, FileAccess.Write, FileShare.None, bufferSize))
                {
                    while (totalRead < mftSize)
                    {
                        uint toRead = (uint)Math.Min(bufferSize, mftSize - totalRead);
                        uint bytesRead;

                        if (!NativeMethods.ReadFile(_volumeHandle, buffer, toRead, out bytesRead, IntPtr.Zero))
                        {
                            LastError = "ReadFile failed at offset " + (mftOffset + totalRead) + ": " + new Win32Exception(Marshal.GetLastWin32Error()).Message;
                            return false;
                        }

                        if (bytesRead == 0) break;

                        outStream.Write(buffer, 0, (int)bytesRead);
                        totalRead += bytesRead;

                        if (progressCallback != null && totalRead % (10 * 1024 * 1024) == 0)
                            progressCallback(totalRead, mftSize);
                    }
                }

                return true;
            }
            catch (Exception ex)
            {
                LastError = "Write error: " + ex.Message;
                return false;
            }
        }

        public byte[] ReadSectors(long offset, int count)
        {
            if (!IsOpen) return null;

            long newPos;
            NativeMethods.SetFilePointerEx(_volumeHandle, offset, out newPos, NativeMethods.FILE_BEGIN);

            byte[] buffer = new byte[count];
            uint bytesRead;
            NativeMethods.ReadFile(_volumeHandle, buffer, (uint)count, out bytesRead, IntPtr.Zero);

            if (bytesRead < count)
            {
                byte[] result = new byte[bytesRead];
                Array.Copy(buffer, result, bytesRead);
                return result;
            }

            return buffer;
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                if (_volumeHandle != NativeMethods.INVALID_HANDLE_VALUE)
                {
                    NativeMethods.CloseHandle(_volumeHandle);
                    _volumeHandle = NativeMethods.INVALID_HANDLE_VALUE;
                }
                _disposed = true;
            }
        }
    }

    public class MFTInfo
    {
        public long MftStartLcn { get; set; }
        public long MftValidDataLength { get; set; }
        public uint BytesPerCluster { get; set; }
        public uint BytesPerSector { get; set; }
        public uint BytesPerFileRecord { get; set; }
        public long TotalClusters { get; set; }
        public long VolumeSerialNumber { get; set; }
    }
}
'@

    try {
        Add-Type -TypeDefinition $csharpCode -Language CSharp -ErrorAction Stop
        Write-ForensicLog -Phase "INIT" -Action "CSHARP_HELPERS_LOADED" -Target "MaPeriT.RawDiskReader" -Result "OK"
        return $true
    } catch {
        if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*ya existe*" -or $_.Exception.Message -like "*MaPeriT*") {
            Write-ForensicLog -Phase "INIT" -Action "CSHARP_HELPERS_YA_CARGADOS" -Target "MaPeriT.RawDiskReader" -Result "OK"
            return $true
        }
        Write-ForensicLog -Phase "INIT" -Action "CSHARP_HELPERS_ERROR" -Target $_.Exception.Message -Result "ERROR"
        return $false
    }
}

function Extract-MFTRaw {
    param(
        [string]$DriveLetter = "C:",
        [string]$OutputPath
    )

    Write-ForensicLog -Phase "FILESYSTEM" -Action "MFT_EXTRACCION_RAW" -Target $DriveLetter

    $reader = $null
    try {
        $reader = New-Object MaPeriT.RawDiskReader

        if (-not $reader.OpenVolume($DriveLetter)) {
            Write-ForensicLog -Phase "FILESYSTEM" -Action "MFT_OPEN_VOLUME_FAILED" -Target $reader.LastError -Result "ERROR"
            return $false
        }

        $volData = $reader.VolumeData
        $mftSizeMB = [math]::Round($volData.MftValidDataLength / 1MB, 2)
        Write-ForensicLog -Phase "FILESYSTEM" -Action "MFT_INFO" -Target "Tamano: ${mftSizeMB}MB, LCN: $($volData.MftStartLcn), Cluster: $($volData.BytesPerCluster)B"

        Write-Host "  [*] Extrayendo MFT ($mftSizeMB MB)..." -ForegroundColor Yellow

        $progressAction = [Action[long,long]]{
            param($current, $total)
            $pct = [math]::Round(($current / $total) * 100)
            Write-Host "`r  [*] MFT: $pct% ($([math]::Round($current/1MB))/$([math]::Round($total/1MB)) MB)" -NoNewline -ForegroundColor Yellow
        }

        $success = $reader.ExtractMFT($OutputPath, $progressAction)
        Write-Host ""

        if ($success) {
            Write-ForensicLog -Phase "FILESYSTEM" -Action "MFT_EXTRAIDA" -Target $OutputPath -Result "OK"
            return $true
        } else {
            Write-ForensicLog -Phase "FILESYSTEM" -Action "MFT_EXTRACCION_FALLIDA" -Target $reader.LastError -Result "ERROR"
            return $false
        }
    } catch {
        Write-ForensicLog -Phase "FILESYSTEM" -Action "MFT_EXCEPCION" -Target $_.Exception.Message -Result "ERROR"
        return $false
    } finally {
        if ($reader) { $reader.Dispose() }
    }
}

function Get-NTFSVolumeInfo {
    param(
        [string]$DriveLetter = "C:"
    )

    $reader = $null
    try {
        $reader = New-Object MaPeriT.RawDiskReader
        if (-not $reader.OpenVolume($DriveLetter)) {
            return $null
        }

        $volData = $reader.VolumeData
        return [PSCustomObject]@{
            VolumeSerialNumber       = "0x{0:X16}" -f $volData.VolumeSerialNumber
            MftStartLcn              = $volData.MftStartLcn
            MftValidDataLengthMB     = [math]::Round($volData.MftValidDataLength / 1MB, 2)
            BytesPerSector           = $volData.BytesPerSector
            BytesPerCluster          = $volData.BytesPerCluster
            BytesPerFileRecord       = $volData.BytesPerFileRecordSegment
            TotalClusters            = $volData.TotalClusters
            FreeClusters             = $volData.FreeClusters
            TotalSizeMB              = [math]::Round(($volData.TotalClusters * $volData.BytesPerCluster) / 1MB, 2)
            FreeSizeMB               = [math]::Round(($volData.FreeClusters * $volData.BytesPerCluster) / 1MB, 2)
        }
    } catch {
        return $null
    } finally {
        if ($reader) { $reader.Dispose() }
    }
}
