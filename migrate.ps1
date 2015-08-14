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

function Wrap-Migration([bool]$goUp) {
    begin {
        $Go = "`r`nGO`r`n`r`n"
    }
    process {
        $fileVersion = $_.Version
        $cmd = "BEGIN TRANSACTION`r`n"
        $cmd += if($goUp) {$_.Migration.Up | Out-String} else {$_.Migration.Down | Out-String}
        $cmd += $Go
        $cmd += if ($goUp) {
            "INSERT [dbo].[schema_migrations] ([Version]) VALUES ('$fileVersion') `r`n"
        } else {
            "DELETE [dbo].[schema_migrations] WHERE Version = '$fileVersion' `r`n"
        }
        $cmd += "COMMIT TRANSACTION" + $Go 

        $cmd
    }
}

$allVersions = Get-AllVersions

if ($Target -eq "")    { $Target = $allVersions | Select-Object -Last 1 }
#add validation

$currentVersion = Get-CurrentVersion -Server $Server -Database $Database

$goUp = $Target -gt $currentVersion
$goDown = $Target -lt $currentVersion

if(-not($goUp -or $goDown)) { 
    Write-Host "No migrations to run."
    exit
}


$pendingVersions = Get-PendingVersions -currentVersion $currentVersion -targetVersion $Target -versions $allVersions

$pendingMigrations = $pendingVersions | Get-Migration


$MigrationScripts = $pendingMigrations | Wrap-Migration -goUp $goUp

$EnvVariables = if (-not (Test-Path "config\$Environment.sql")) { 
    "-- No environment variables for $Environment environment. You can add config/$Environment.sql file when needed. --" 
} else {
    Get-Content "config\$Environment.sql"
}

$EnvVariables + "`r`n`r`n" | Out-File -FilePath migration.sql

$MigrationScripts | ForEach-Object -Process { $_ | Out-File -FilePath migration.sql -Append }


SQLCMD.EXE -S $Server -d $Database -E -i migration.sql -b