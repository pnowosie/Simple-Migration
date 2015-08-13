param(
    [string]$Server         = "localhost", #= $(throw "Server required."),
    [string]$Database       = $(throw "Database required."),
    [string]$Environment    = "DEV",
    [string]$Target
)

function Get-CurrentVersion(
    [string]$Server         = $(throw "Server required."),
    [string]$Database       = $(throw "Database required."))
{
    SQLCMD.EXE -S $Server -d $Database -E -i  print-current-version.sql -b
}

function Get-AllVersions
{
    $zero = @("0")
    $migrationTimestamps =
        Get-ChildItem 'sql\*.sql' |
        Split-Path -Leaf |
        Select-Object @{ Name="Timestamp"; Expression={ $_.Substring(0, $_.IndexOf("_"))} } |
        Select-Object -ExpandProperty Timestamp |
        Sort-Object
        
    $zero + $migrationTimestamps
}

function Get-PendingVersions(
    [string]$currentVersion,
    [string]$targetVersion,
    [string[]]$versions)
{
    if ($targetVersion -gt $currentVersion) {
        $versions | Where-Object { $_ -gt $currentVersion -and $_ -le $targetVersion }
    } elseif ($targetVersion -lt $currentVersion) {
        $versions | Where-Object { $_ -le $currentVersion -and $_ -gt $targetVersion} | Sort-Object -Descending
    } else {
        @()
    }
}

function Skip-While([scriptblock]$pred = $(throw "Need a predicate")) {
    begin { $take = $false }
    process {
        $take = $take -or (-not (& $pred $_))
        if ($take) {
            $_
        }
    }
}

function Take-While() {
    param ( [scriptblock]$pred = $(throw "Need a predicate"))
    begin { $take = $true }
    process {
        $take = $take -and (& $pred $_)
        if ( $take ) {
            $_
        }
    }
}

function Skip-Count() {
    param ( [int]$count = $(throw "Need a count") )
    begin { $total = 0 }
    process {
        if ($total -ge $count) {
            $_
        }
        $total += 1
    }
}

function Parse-Section([string]$beginToken, [string]$endToken, [string[]]$scriptLines) {
    $scriptLines |
        Skip-While {-not ($_ -match "$beginToken.*")} |
        Skip-Count 1 |
        Take-While {-not ($_ -match "$endToken.*")  }
}

function Parse-Migration([string[]]$scriptLines) {
    @{
        Up = Parse-Section -beginToken "BEGIN_SETUP:" -endToken "END_SETUP:" -scriptLines $scriptLines;
        Down = Parse-Section -beginToken "BEGIN_TEARDOWN:" -endToken "END_TEARDOWN:" -scriptLines $scriptLines
    }
}

function Get-ScriptByVersion([string]$version) {
    Get-ChildItem "sql\$version*.sql" | Get-Content
}

function Get-Migration() {
    process {
        [string]$version = $_
        $scriptLines = Get-ScriptByVersion $version
        @{ Version =  $version; Migration = Parse-Migration -scriptLines $scriptLines }
    }
}

$allVersions = Get-AllVersions

if ($Target -eq "")    { $Target = $allVersions | Select-Object -Last 1 }
#add validation

$goUp = $Target -gt $currentVersion
$goDown = $Target -lt $currentVersion

if(-not($goUp -or $goDown)) { 
    Write-Host "No migrations to run."
    exit
}

$currentVersion = Get-CurrentVersion -Server $Server -Database $Database
$pendingVersions = Get-PendingVersions -currentVersion $currentVersion -targetVersion $Target -versions $allVersions

$pendingMigrations = $pendingVersions | Get-Migration

