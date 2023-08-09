DECLARE @SnapshotName sysname;
DECLARE @SQL nvarchar(max);
DECLARE @sourceDb sysname;
DECLARE @sourceLogicalName sysname;
DECLARE @sourcePath nvarchar(512);
DECLARE @parameters nvarchar(MAX); 

SET @sourceDb = 'DOSTOP_ZUNANJI';

SELECT @sourceLogicalName = name
FROM sys.master_files 
WHERE database_id = DB_ID(@sourceDb) 
AND type_desc = 'ROWS'

SELECT @sourcePath = LEFT(physical_name, LEN(physical_name)- CHARINDEX('\',REVERSE(physical_name))) 
FROM sys.master_files 
WHERE database_id = DB_ID(@sourceDb) 
AND type_desc = 'ROWS'

SET @SnapshotName = @sourceDb +'_dbss_' + replace(convert(varchar(5),getdate(),108), ':', '') + '_' + convert(varchar, getdate(), 112)
SET @SQL = N'CREATE DATABASE ' + @SnapshotName + ' CONTAINMENT = NONE ON ( NAME = N''' + @sourceLogicalName + ''', FILENAME = N'''+ @sourcePath + '\' + @SnapshotName + ''' ) AS SNAPSHOT OF [' + @sourceDb + ']'


EXEC sp_executesql @SQL