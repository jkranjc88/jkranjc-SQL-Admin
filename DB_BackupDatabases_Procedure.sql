-- Script to backup databases and delete old ones
USE [master]  
GO  
/****** Object:  StoredProcedure [dbo].[sp_BackupDatabases] ******/  
SET ANSI_NULLS ON  
GO  
SET QUOTED_IDENTIFIER ON  
GO  
-- =============================================  
-- Author: Microsoft  
-- Create date: 2010-02-06 
-- Description: Backup Databases for SQLExpress 
-- Parameter1: databaseName  
-- Parameter2: backupType F=full, D=differential, L=log 
-- Parameter3: backup file location 

-- Update: Jure Kranjc SnT Iskratel
-- Update date: 2022-12-01
-- Description: Added additional parameters, added backup deletion
-- Parameter4: delete old backups, N = No, Y = Yes
-- Parameter5: delete backups older than n hours
-- ============================================= 
CREATE OR ALTER PROCEDURE [dbo].[sp_BackupDatabases_DeleteOld]   
            @databaseName sysname = null, 
            @backupType CHAR(1) = 'F', 
            @backupLocation nvarchar(200),
			@deleteOld varchar(1) = 'N',
			@backupAge_hrs int = 720
			
AS  
SET NOCOUNT ON;  

IF (NOT EXISTS (SELECT 1 
					FROM INFORMATION_SCHEMA.TABLES 
					WHERE TABLE_SCHEMA = 'dbo' 
					AND  TABLE_NAME = 'BackupLog'))
BEGIN
	CREATE TABLE dbo.BackupLog 
		(
		ID int IDENTITY PRIMARY KEY, 
		DBname sysname,
		BackupType varchar(1),
		Status varchar(10),
		MessageLog varchar(500),
		ErrorMessage varchar(500) default null,
		DateTime DateTime
		)
END

DECLARE @DBs TABLE 
		( 
		ID int IDENTITY PRIMARY KEY, 
		DBNAME sysname
        ) 
	-- Pick out only databases which are online in case ALL databases are chosen to be backed up 
	-- If specific database is chosen to be backed up only pick that out from @DBs 
	INSERT INTO @DBs (DBNAME) 
	SELECT Name FROM master.sys.databases 
		where state=0 
		AND name= ISNULL(@databaseName ,name)
		AND database_id > 4 -- returns only User Tables
		ORDER BY Name
-- Declare variables 
DECLARE @BackupName nvarchar(100) 
DECLARE @BackupFile nvarchar(300) 
DECLARE @DBNAME nvarchar(300) 
DECLARE @sqlCommand NVARCHAR(1000)  
DECLARE @dateTime NVARCHAR(20) 
DECLARE @Loop int                   
-- Loop through the databases one by one 
SELECT @Loop = min(ID) FROM @DBs 
 WHILE @Loop IS NOT NULL 
	BEGIN 
-- Database Names have to be in [dbname] format since some have - or _ in their name 
      SET @DBNAME = '['+(SELECT DBNAME FROM @DBs WHERE ID = @Loop)+']' 
-- Set the current date and time n yyyyhhmmss format 
      SET @dateTime = REPLACE(CONVERT(VARCHAR, GETDATE(),101),'/','') + '_' +  REPLACE(CONVERT(VARCHAR, GETDATE(),108),':','')   
-- Create backup filename in path\filename.extension format for full,diff and log backups 
      IF @backupType = 'F' 
            SET @BackupFile = @backupLocation+REPLACE(REPLACE(@DBNAME, '[',''),']','')+ '_FULL_'+ @dateTime+ '.BAK' 
      ELSE IF @backupType = 'D' 
            SET @BackupFile = @backupLocation+REPLACE(REPLACE(@DBNAME, '[',''),']','')+ '_DIFF_'+ @dateTime+ '.BAK' 
      ELSE IF @backupType = 'L' 
            SET @BackupFile = @backupLocation+REPLACE(REPLACE(@DBNAME, '[',''),']','')+ '_LOG_'+ @dateTime+ '.TRN' 
-- Provide the backup a name for storing in the media 
      IF @backupType = 'F' 
            SET @BackupName = REPLACE(REPLACE(@DBNAME,'[',''),']','') +' full backup for '+ @dateTime 
      IF @backupType = 'D' 
            SET @BackupName = REPLACE(REPLACE(@DBNAME,'[',''),']','') +' differential backup for '+ @dateTime 
      IF @backupType = 'L' 
            SET @BackupName = REPLACE(REPLACE(@DBNAME,'[',''),']','') +' log backup for '+ @dateTime 
-- Generate the dynamic SQL command to be executed 

       IF @backupType = 'F'  
		BEGIN TRY
			SET @sqlCommand = 'BACKUP DATABASE ' +@DBNAME+  ' TO DISK = '''+@BackupFile+ ''' WITH INIT, NAME= ''' +@BackupName+''', NOSKIP, NOFORMAT' 
			EXEC sp_executesql @sqlCommand
			INSERT INTO dbo.BackupLog (DBname ,BackupType, Status, MessageLog, DateTime)
			VALUES (@DBNAME, @backupType, 'Success', 'BackupType ' + @backupType + ' Successfuly finished for database ' +@DBNAME, (SELECT GETDATE()) )                  
		END TRY 
		BEGIN CATCH 
			INSERT INTO dbo.BackupLog (DBname ,BackupType, Status, MessageLog, ErrorMessage, DateTime)
			VALUES (@DBNAME, @backupType, 'Error', 'BackupType ' + @backupType + ' failed for database ' +@DBNAME, (SELECT ERROR_MESSAGE()), (SELECT GETDATE()) ) 
		END CATCH  
       
	   IF @backupType = 'D' 
		BEGIN TRY
			SET @sqlCommand = 'BACKUP DATABASE ' +@DBNAME+  ' TO DISK = '''+@BackupFile+ ''' WITH DIFFERENTIAL, INIT, NAME= ''' +@BackupName+''', NOSKIP, NOFORMAT'
			EXEC sp_executesql @sqlCommand
			INSERT INTO dbo.BackupLog (DBname ,BackupType, Status, MessageLog, DateTime)
			VALUES (@DBNAME, @backupType, 'Success', 'BackupType ' + @backupType + ' Successfuly finished for database ' +@DBNAME, (SELECT GETDATE()) ) 
		END TRY 
		BEGIN CATCH
			INSERT INTO dbo.BackupLog (DBname ,BackupType, Status, MessageLog, ErrorMessage, DateTime)
			VALUES (@DBNAME, @backupType, 'Error', 'BackupType ' + @backupType + ' failed for database ' +@DBNAME, (SELECT ERROR_MESSAGE()), (SELECT GETDATE()) ) 
		END CATCH  
       
	   IF @backupType = 'L'  
		BEGIN TRY 
			SET @sqlCommand = 'BACKUP LOG ' +@DBNAME+  ' TO DISK = '''+@BackupFile+ ''' WITH INIT, NAME= ''' +@BackupName+''', NOSKIP, NOFORMAT'
			EXEC sp_executesql @sqlCommand
			INSERT INTO dbo.BackupLog (DBname ,BackupType, Status, MessageLog, DateTime)
			VALUES (@DBNAME, @backupType, 'Success', 'BackupType ' + @backupType + ' Successfuly finished for database ' +@DBNAME, (SELECT GETDATE()) ) 
		END TRY  
		BEGIN CATCH  
			INSERT INTO dbo.BackupLog (DBname ,BackupType, Status, MessageLog, ErrorMessage, DateTime)
			VALUES (@DBNAME, @backupType, 'Error', 'BackupType ' + @backupType + ' failed for database ' +@DBNAME, (SELECT ERROR_MESSAGE()), (SELECT GETDATE()) ) 
		END CATCH

	-- Execute the generated SQL command       
	-- Goto the next database

	SELECT @Loop = min(ID) FROM @DBs where ID>@Loop 
	END
	-- End of Loop
	-- START of delete
BEGIN
	IF @deleteOld ='N'
	BEGIN 
		RETURN 0		
	END
	ELSE IF	@deleteOld = 'Y'
		BEGIN
			DECLARE @DeleteDate NVARCHAR(50)
			DECLARE @DeleteDateTime DATETIME

			SET @DeleteDateTime = DateAdd(hh, - @backupAge_hrs, GetDate())
			SET @DeleteDate = (Select Replace(Convert(nvarchar, @DeleteDateTime, 111), '/', '-') + 'T' + Convert(nvarchar, @DeleteDateTime, 108))

			EXECUTE master.dbo.xp_delete_file 0, @backupLocation, 'bak', @DeleteDate, 1
			EXECUTE master.dbo.xp_delete_file 0, @backupLocation, 'trn', @DeleteDate, 1
	END
END