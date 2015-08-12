# Copyright 2010 - 2011 Adam Boddington
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

param(
    [string]$Server         = "localhost", #= $(throw "Server required."),
    [string]$Database       = $(throw "Database required."),
    [string]$Environment    = "DEV",
    [string]$Target
)

$ErrorActionPreference = "Stop"

"" # Write line.

# Ensure the Version table exists and has a record.
SQLCMD.EXE -S $Server -d $Database -E -i ensure-version-table.sql -b
""

# Get the current version from the database.
$CurrentVersion = SQLCMD.EXE -S $Server -d $Database -E -i  print-current-version.sql -b

# Find all migrations. Each subdirectory is a migration.
$MigrationFiles = Get-ChildItem 'sql\*.sql'

if (!$MigrationFiles) { "No migrations to run."; ""; exit }

$Migrations = @("0") + ($MigrationFiles | ForEach-Object -Process { $_.Name.Substring(0, $_.Name.IndexOf("_")) })

$CurrentVersionIndex = [array]::IndexOf($Migrations, $CurrentVersion)

if ($CurrentVersionIndex -eq -1) { throw "Current version not found. (" + $CurrentVersion + ")" }

"Current Version: " + $CurrentVersion

# Determine target version index from the flags or target.
if ($Target -eq "")    { $TargetVersionIndex = $Migrations.Count - 1 }
else                   { $TargetVersionIndex = [array]::IndexOf($Migrations, $Target) }

if ($TargetVersionIndex -eq -1) { throw "Target version not found. (" + $Target + ")" }

$TargetVersion = $Migrations[$TargetVersionIndex]

" Target Version: " + $TargetVersion
""

if ($CurrentVersionIndex -eq $TargetVersionIndex) { "No migrations to run."; ""; exit }

# Initialise an empty array to collect the migration scripts.
$MigrationScripts = @()

# Collect the up migration scripts.
$goUp = $CurrentVersionIndex + 1 -le $TargetVersionIndex;
for ($x = $CurrentVersionIndex + 1; $x -le $TargetVersionIndex; $x++) {
    $MigrationScripts += Get-ChildItem "sql\$($Migrations[$x])*" | Select-Object -ExpandProperty FullName
}

# Collect the down migration scripts.
$goDown = $CurrentVersionIndex -gt $TargetVersionIndex;
for ($x = $CurrentVersionIndex; $x -gt $TargetVersionIndex; $x--) {
    $MigrationScripts += Get-ChildItem "sql\$($Migrations[$x])*" | Select-Object -ExpandProperty FullName
}

if ($goUp -and $goDown) { throw "Invalid operation: cannot go up and down" }

"Migration Scripts"
"================="
$MigrationScripts | ForEach-Object { Split-Path $_ -Leaf }
""

# Build the migration script.
$beginToken = if ($goUp) {"BEGIN_SETUP:"} else {"BEGIN_TEARDOWN:"}
$endToken   = if ($goUp) {"END_SETUP:"  } else {"END_TEARDOWN:"  }

if (-not (Test-Path "config\$Environment.sql")) { 
    $EnvVariables = "--  No environment variables for $Environment environment. You can add config/$Environment.sql file when needed. --" 
} else {
    $EnvVariables = Get-Content "config\$Environment.sql"
}
$EnvVariables + "`r`n`r`n" | Out-File -FilePath migration.sql
$MigrationScripts | Where-Object {$_ -ne $null} | ForEach-Object -Process {
    $file = Get-Content -Path $_;
    $filename= Split-Path $_ -Leaf 
    $fileVersion= $filename.Substring(0, $filename.IndexOf("_"))
    $begin      = [array]::IndexOf($file, $beginToken)+1;
    $end        = [array]::IndexOf($file, $endToken)  -1;
    $cmd   = $file[$begin..$end] | Out-String
    $Go = "`r`nGO`r`n"
    "BEGIN TRANSACTION" | Out-File -FilePath migration.sql -Append
    $cmd + $Go | Out-File -FilePath migration.sql -Append 
    if ($goUp) {
        "INSERT [dbo].[schema_migrations] ([Version]) VALUES ('$fileVersion') " | Out-File -FilePath migration.sql -Append
    } else {
        "DELETE [dbo].[schema_migrations] WHERE Version = '$fileVersion' " | Out-File -FilePath migration.sql -Append
    }
    "COMMIT TRANSACTION" + $Go | Out-File -FilePath migration.sql -Append
}


# Execute the migration script.
"Executing Migration Scripts"
"==========================="
SQLCMD.EXE -S $Server -d $Database -E -i migration.sql -b
""