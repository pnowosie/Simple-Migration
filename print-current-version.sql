DECLARE @CurrentVersion [nvarchar](100)
SELECT @CurrentVersion = MAX([version]) FROM [dbo].[schema_migrations]
PRINT @CurrentVersion
