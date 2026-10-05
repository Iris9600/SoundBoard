param(
    [ValidateSet('Audit', 'Migrate')][string]$Mode = 'Audit',
    [string]$DeviceName,
    [string]$DeviceId,
    [switch]$ImportMock
)

$ErrorActionPreference = 'Stop'
$projectId = 'soundboard-95778'
$databaseName = "projects/$projectId/databases/(default)"
$documentRoot = "$databaseName/documents"
$apiRoot = "https://firestore.googleapis.com/v1/$documentRoot"

# Capture all CLI output: never print credentials or tokens.
$ErrorActionPreference = 'Continue' # Windows PowerShell treats CLI progress on stderr as errors.
$projectJson = firebase.cmd projects:list --json 2>$null | Out-String
$projectExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
$projectResult = $projectJson | ConvertFrom-Json
if ($projectExitCode -ne 0 -or $projectResult.status -ne 'success') { throw 'Firebase login needs renewal. Run firebase.cmd login --reauth.' }
if ($projectId -notin $projectResult.result.projectId) { throw 'Logged-in account cannot access the SoundBoard project.' }
$loginResult = firebase.cmd login:list --json | Out-String | ConvertFrom-Json
$headers = @{ Authorization = 'Bearer ' + $loginResult.result[0].tokens.access_token }

function Invoke-Firestore([string]$Uri, [string]$Method = 'Get', $Body = $null) {
    $arguments = @{ Uri = $Uri; Method = $Method; Headers = $headers }
    if ($null -ne $Body) {
        $arguments.ContentType = 'application/json; charset=utf-8'
        $arguments.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 60 -Compress))
    }
    Invoke-RestMethod @arguments
}

function Read-Collection([string]$Path) {
    $pageToken = $null
    do {
        $uri = "$apiRoot/${Path}?pageSize=100"
        if ($pageToken) { $uri += '&pageToken=' + [uri]::EscapeDataString($pageToken) }
        $page = Invoke-Firestore $uri
        foreach ($document in $page.documents) { $document }
        $pageToken = $page.nextPageToken
    } while ($pageToken)
}

function Show-Document($Document) {
    $relativePath = $Document.name.Substring($documentRoot.Length + 1)
    [pscustomobject]@{
        path = $relativePath
        name = $Document.fields.name.stringValue
        deviceId = $Document.fields.deviceId.stringValue
        deviceName = $Document.fields.deviceName.stringValue
    } | ConvertTo-Json -Compress
}

$legacy = @(Read-Collection 'Sound')
if ($Mode -eq 'Audit') {
    $collections = Invoke-Firestore "$apiRoot`:listCollectionIds" 'Post' @{ pageSize = 100 }
    Write-Output ('Root collections: ' + ($collections.collectionIds -join ', '))
    foreach ($document in $legacy) { Show-Document $document }
    foreach ($document in @(Read-Collection 'devices')) { Show-Document $document }
    $query = @{ structuredQuery = @{ from = @(@{ collectionId = 'sounds'; allDescendants = $true }) } }
    $results = Invoke-Firestore "$apiRoot`:runQuery" 'Post' $query
    foreach ($result in $results) { if ($result.document) { Show-Document $result.document } }
    exit 0
}

if ([string]::IsNullOrWhiteSpace($DeviceName)) { throw 'Migration requires an explicit device name.' }
if ($DeviceId -notmatch '^[a-f0-9]{32}$') { throw 'Provide a 32-character lowercase hexadecimal device ID.' }
if ($legacy.Count -gt 100) { throw 'This migration supports up to 100 legacy records in one atomic commit.' }
foreach ($document in $legacy) {
    if ($document.fields.deviceId.stringValue -and $document.fields.deviceId.stringValue -ne $DeviceId) {
        throw "Record $($document.name) already belongs to a different device."
    }
}

# Preserve every original field, audio data, document ID and timestamp locally.
$backupDirectory = Join-Path $PSScriptRoot '../.firebase-data-backups'
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
$backupPath = Join-Path $backupDirectory ("legacy-Sound-" + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ') + '.json')
@{ projectId = $projectId; deviceId = $DeviceId; deviceName = $DeviceName; documents = $legacy } |
    ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $backupPath -Encoding UTF8
$savedBackup = Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json
if (@($savedBackup.documents).Count -ne $legacy.Count) { throw 'Backup verification failed.' }

$writes = [Collections.Generic.List[object]]::new()
$now = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
$devicePath = "$documentRoot/devices/$DeviceId"
$writes.Add(@{
    update = @{ name = $devicePath; fields = @{
        deviceId = @{ stringValue = $DeviceId }
        deviceName = @{ stringValue = $DeviceName }
        updatedAt = @{ timestampValue = $now }
    } }
    updateMask = @{ fieldPaths = @('deviceId', 'deviceName', 'updatedAt') }
})

foreach ($document in $legacy) {
    $soundId = $document.name.Substring($document.name.LastIndexOf('/') + 1)
    $fields = @{}
    foreach ($property in $document.fields.PSObject.Properties) { $fields[$property.Name] = $property.Value }
    $fields.deviceId = @{ stringValue = $DeviceId }
    $fields.deviceName = @{ stringValue = $DeviceName }
    $writes.Add(@{
        update = @{ name = "$devicePath/sounds/$soundId"; fields = $fields }
        currentDocument = @{ exists = $false }
    })
    # Both create and delete are committed atomically. Abort on concurrent edits.
    $writes.Add(@{ delete = $document.name; currentDocument = @{ updateTime = $document.updateTime } })
}

if ($ImportMock) {
    # Generate a playable 0.15 second mono PCM WAV tone; no external assets.
    $sampleRate = 8000
    $samples = 1200
    $stream = [IO.MemoryStream]::new()
    $writer = [IO.BinaryWriter]::new($stream)
    $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
    $writer.Write([int](36 + $samples * 2))
    $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
    $writer.Write([int]16); $writer.Write([int16]1); $writer.Write([int16]1)
    $writer.Write([int]$sampleRate); $writer.Write([int]($sampleRate * 2))
    $writer.Write([int16]2); $writer.Write([int16]16)
    $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
    $writer.Write([int]($samples * 2))
    for ($sample = 0; $sample -lt $samples; $sample++) {
        $writer.Write([int16](3000 * [Math]::Sin(2 * [Math]::PI * 440 * $sample / $sampleRate)))
    }
    $writer.Flush()
    $mockAudio = [Convert]::ToBase64String($stream.ToArray())
    $writer.Dispose(); $stream.Dispose()
    $writes.Add(@{
        update = @{ name = "$devicePath/sounds/mock-device-storage-test"; fields = @{
            deviceId = @{ stringValue = $DeviceId }
            deviceName = @{ stringValue = $DeviceName }
            name = @{ stringValue = 'Mock device storage test' }
            url = @{ stringValue = $mockAudio }
            createdAt = @{ timestampValue = $now }
            isMock = @{ booleanValue = $true }
        } }
        currentDocument = @{ exists = $false }
    })
}

$commit = Invoke-Firestore "https://firestore.googleapis.com/v1/$databaseName/documents:commit" 'Post' @{ writes = $writes.ToArray() }
if (@($commit.writeResults).Count -ne $writes.Count) { throw 'Unexpected commit result. Inspect database before retrying.' }
$profile = Invoke-Firestore "$apiRoot/devices/$DeviceId"
if ($profile.fields.deviceName.stringValue -ne $DeviceName) { throw 'Device profile verification failed.' }
$stored = @(Read-Collection "devices/$DeviceId/sounds")
foreach ($document in $stored) {
    if ($document.fields.deviceId.stringValue -ne $DeviceId -or $document.fields.deviceName.stringValue -ne $DeviceName) {
        throw "Ownership verification failed for $($document.name)."
    }
}
foreach ($original in $legacy) {
    $soundId = $original.name.Substring($original.name.LastIndexOf('/') + 1)
    $copy = @($stored | Where-Object { $_.name -eq "$devicePath/sounds/$soundId" })
    if ($copy.Count -ne 1) { throw "Missing migrated sound: $soundId" }
    foreach ($property in $original.fields.PSObject.Properties) {
        if ($property.Name -in @('deviceId', 'deviceName')) { continue }
        $expected = $property.Value | ConvertTo-Json -Depth 60 -Compress
        $actual = $copy[0].fields.($property.Name) | ConvertTo-Json -Depth 60 -Compress
        if ($expected -ne $actual) { throw "Field preservation verification failed: $soundId / $($property.Name)" }
    }
}
if (@(Read-Collection 'Sound').Count -ne 0) { throw 'Legacy collection is not empty; new records may have been added by an old app.' }
if ($ImportMock) {
    $mock = @($stored | Where-Object { $_.name -eq "$devicePath/sounds/mock-device-storage-test" })
    if ($mock.Count -ne 1 -or $mock[0].fields.url.stringValue -ne $mockAudio) { throw 'Mock read-back verification failed.' }
}
Write-Output "Verified $($legacy.Count) migrated sounds and $([int]$ImportMock.IsPresent) mock sound for $DeviceName ($DeviceId)."
Write-Output "Backup: $backupPath"
foreach ($document in $stored) { Show-Document $document }
