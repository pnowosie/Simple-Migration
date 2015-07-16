PRINT 'Checking the existence of the Version table.'
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[schema_migrations]') AND type IN (N'U'))
BEGIN
    PRINT 'The Version table does not exist.'
    PRINT 'Creating the Version table...'
    CREATE TABLE [dbo].[schema_migrations] ([version] [nvarchar](100) NOT NULL, [created_at] [datetime] default (GetDate()))
END

PRINT 'Checking the existence of a row in the Version table.'
IF NOT EXISTS (SELECT 1 FROM [dbo].[schema_migrations])
BEGIN
    PRINT 'A row does not exist in the Version table.'
    PRINT 'Creating a row in the Version table...'
    INSERT [dbo].[schema_migrations] (version) VALUES ('0')
END
