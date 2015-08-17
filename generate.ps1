param([string]$MigrationName = $(throw "MigrationName required."))

# Create directories if needed
if (-not (Test-Path sql    -PathType container)) { md sql    | Out-Null }
if (-not (Test-Path config -PathType container)) { md config | Out-Null }

$cannonicalMigrationName = $MigrationName.Replace(' ', '_')

"BEGIN_SETUP:



END_SETUP:

BEGIN_TEARDOWN:



END_TEARDOWN:" |
Out-File -FilePath "sql\$([DateTime]::Now.ToString("yyyyMMddHHmmss"))_$cannonicalMigrationName.sql"