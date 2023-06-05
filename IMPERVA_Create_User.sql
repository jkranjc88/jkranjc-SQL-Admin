/* 
@UserName = Set username for login / user to grant rights to
@UserDB: 1 - Grant Select on USER databases
		0	- Grant Select ONLY on Master database

@Print: 1 - print command
		0 - execute command
*/

/* Sanity switch */
RAISEERROR ('Saved you from F5 autorun!', -1, -1);

DECLARE @UserName varchar(100) = 'franja'
DECLARE @UserDB bit = 1
DECLARE @Print bit = 0
DECLARE @DB_Name varchar(100) 
DECLARE @Command nvarchar(4000) 

IF (@Print = 1)
	BEGIN
		BEGIN
			    PRINT 'USE "master"; 
				CREATE USER ' + @UserName + ' FOR LOGIN ' + @UserName + ' WITH DEFAULT_SCHEMA=[dbo];
				GRANT VIEW ANY DEFINITION TO ' + @UserName + ';'
		END
	END
	ELSE
	BEGIN
			BEGIN
			    SELECT @Command =  'USE "master"; CREATE USER ' +@UserName + ' FOR LOGIN ' + @UserName + ' WITH DEFAULT_SCHEMA=[dbo];
				GRANT VIEW ANY DEFINITION TO ' + @UserName + ';'
				EXEC sp_executesql @Command
			END
	END

SELECT @Command = 'USE master; 
GRANT SELECT ON "master".sys.databases TO ' + @UserName +';
GRANT SELECT ON "master".sys.server_principals TO ' + @UserName +';
GRANT SELECT ON "master".sys.server_permissions TO ' + @UserName +';
GRANT SELECT ON "master".sys.server_role_members TO ' + @UserName

IF (@Print = 1)
BEGIN
	PRINT @Command
END
ELSE
BEGIN
	EXEC sp_executesql @Command
END

IF (@UserDB = 1)
BEGIN
/* Create list of databases to grant select on */
DECLARE database_cursor CURSOR FOR 
SELECT name 
FROM MASTER.sys.databases where name != 'master'

OPEN database_cursor 

FETCH NEXT FROM database_cursor INTO @DB_Name 

WHILE @@FETCH_STATUS = 0 
BEGIN 

IF (@Print = 1)
	BEGIN
		PRINT 'USE "' + @DB_Name + '"; 
		CREATE USER ' +@UserName + ' FOR LOGIN ' + @UserName + ' WITH DEFAULT_SCHEMA=[dbo]'
	END
	ELSE
	BEGIN
	    SELECT @Command =  'USE "' + @DB_Name + '";CREATE USER ' +@UserName + ' FOR LOGIN ' + @UserName + ' WITH DEFAULT_SCHEMA=[dbo]'
        EXEC sp_executesql @Command
	END


     SELECT @Command = 'USE "' + @DB_Name + '";
	 GRANT SELECT ON "' + @DB_Name + '".sys.schemas TO ' + @UserName +';
	 GRANT SELECT ON "' + @DB_Name + '".sys.all_objects TO ' + @UserName +';
	 GRANT SELECT ON "' + @DB_Name + '".sys.database_principals TO ' + @UserName +';
	 GRANT SELECT ON "' + @DB_Name + '".sys.database_permissions TO ' + @UserName +';
	 GRANT SELECT ON "' + @DB_Name + '".sys.database_role_members TO ' + @UserName +';'

	IF (@Print = 1)
	BEGIN
		PRINT @Command
	END
	ELSE
	BEGIN
		EXEC sp_executesql @Command
	END

     FETCH NEXT FROM database_cursor INTO @DB_Name 
END 

CLOSE database_cursor 
DEALLOCATE database_cursor
END