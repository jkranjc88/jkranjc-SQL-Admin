USE [master];
GO

CREATE PROCEDURE dbo.sp_ineachdb
  @command nvarchar(max)
AS
BEGIN
  DECLARE @context nvarchar(150),
          @sx      nvarchar(18) = N'.sys.sp_executesql',
          @db      sysname;
  CREATE TABLE #dbs(name sysname PRIMARY KEY);

  INSERT #dbs(name) SELECT QUOTENAME(name) 
    FROM sys.databases
    WHERE [state] & 992 = 0 –- accessible
    AND DATABASEPROPERTYEX(name, 'UserAccess') <> 'SINGLE_USER' 
    AND HAS_DBACCESS(name) = 1;

  DECLARE dbs CURSOR LOCAL FAST_FORWARD
    FOR SELECT name, name + @sx FROM #dbs;

  OPEN dbs;

  FETCH NEXT FROM dbs INTO @db, @context;

  DECLARE @msg nvarchar(512) = N'Could not run against %s : %s.',
          @err nvarchar(max);

  WHILE @@FETCH_STATUS <> -1
  BEGIN

    BEGIN TRY
      EXEC @context @command = @command;
    END TRY
    BEGIN CATCH
      SET @err = ERROR_MESSAGE();
      RAISERROR(@msg, 1, 0, @db, @err);
    END CATCH

    FETCH NEXT FROM dbs INTO @db, @context;
  END

  CLOSE dbs; DEALLOCATE dbs;

END
GO

EXEC sys.sp_MS_marksystemobject N'sp_ineachdb';	
