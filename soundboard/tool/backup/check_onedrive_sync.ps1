param([Parameter(Mandatory = $true)][string]$Folder)
$ErrorActionPreference = 'Stop'

# Check Windows Cloud Files' provider-confirmed IN_SYNC flag, not just file existence.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class SoundBackupCloudState {
    [StructLayout(LayoutKind.Sequential)]
    public struct AttributeTag { public uint Attributes; public uint Tag; }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFileW(string path, uint access, uint share,
        IntPtr security, uint disposition, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetFileInformationByHandleEx(SafeFileHandle handle, int infoClass,
        out AttributeTag info, uint size);
    [DllImport("cldapi.dll")]
    private static extern uint CfGetPlaceholderStateFromAttributeTag(uint attributes, uint tag);
    public static bool InSync(string path) {
        using (var handle = CreateFileW(path, 0, 7, IntPtr.Zero, 3, 0x02000000, IntPtr.Zero)) {
            if (handle.IsInvalid) return false;
            AttributeTag info;
            if (!GetFileInformationByHandleEx(handle, 9, out info, 8)) return false;
            uint state = CfGetPlaceholderStateFromAttributeTag(info.Attributes, info.Tag);
            return state != 0xffffffff && (state & 1) != 0 && (state & 8) != 0;
        }
    }
}
'@

$items = @(Get-ChildItem -LiteralPath $Folder -Recurse -File -Force)
$pending = @($items | Where-Object { -not [SoundBackupCloudState]::InSync($_.FullName) })
@{ synced = ($items.Count -gt 0 -and $pending.Count -eq 0); totalFiles = $items.Count; pendingFiles = $pending.Count } |
    ConvertTo-Json -Compress
