param([string]$MigrationName = $(throw "MigrationName required."))

$cannonicalMigrationName = $MigrationName.Replace(' ', '_')

"BEGIN_SETUP:



END_SETUP:

BEGIN_TEARDOWN:



END_TEARDOWN:" |
Out-File -FilePath "sql\$([DateTime]::Now.ToString("yyyyMMddHHmmss"))_$cannonicalMigrationName.sql"