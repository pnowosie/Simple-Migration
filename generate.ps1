<#
.SYNOPSIS
Simple-Migration: dead simple M$SQL migrations

.DESCRIPTION
Powershell solution for Microsoft SQL Server database migration and versioning, based on Adam Boddington's idea.
It is open-sourced, MIT-licenced, easy customise, fully extendable and happy usable.

.PARAMETER MigrationName
Migration script file name, timestamp and .sql extension will be added for you.

.EXAMPLE
generate.ps1 "Add colmn TotalGross to the InvoicePosition table"
Create file in sql directory named like '20150814114919_Add_colmn_TotalGross_to_the_InvoicePosition_table.sql'. 
Create also <sql> and <config> directories if missing. File content is divided in two parts: UP and DOWN migration scripts.

.NOTES
Licensed under the MIT License.
GitHub repository page:              https://github.com/pnowosie/Simple-Migration
#>
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage='Migration script file name, timestamp and .sql extension will be added')]
    [string]$MigrationName
)

# Create directories if needed
if (-not (Test-Path sql    -PathType container)) { md sql    | Out-Null }
if (-not (Test-Path config -PathType container)) { md config | Out-Null }

$cannonicalMigrationName = $MigrationName.Replace(' ', '_')

"BEGIN_SETUP:



END_SETUP:

BEGIN_TEARDOWN:



END_TEARDOWN:" |
Out-File -FilePath "sql\$([DateTime]::Now.ToString("yyyyMMddHHmmss"))_$cannonicalMigrationName.sql"
