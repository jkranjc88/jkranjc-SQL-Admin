


USE [master]
GO

/****** Object:  StoredProcedure [dbo].[transferLoginsAGL]    Script Date: 28. 10. 2021 09:12:18 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[transferLoginsAGL]
AS
SET NOCOUNT ON
--IM171201<171003-1114<171002-1457

CREATE TABLE #tmpLoginTable(	Loginname nvarchar(256),CScript nvarchar(max),AScript nvarchar(max))

IF((SELECT role FROM sys.dm_hadr_availability_replica_states WHERE is_local = 1 AND group_id = '31FFC1A3-916D-4108-83AD-789BA51B9CFB')= 1)
	BEGIN  --- vP
	 
		IF (NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND  TABLE_NAME = 'agLoginTable')) 
		BEGIN  
			CREATE TABLE agLoginTable (Loginname nvarchar(256),CScript nvarchar(4000),AScript nvarchar(4000)) 
		END 
		ELSE 
		BEGIN 
			TRUNCATE TABLE master.[dbo].[agLoginTable] 
		END

		INSERT INTO agLoginTable
		SELECT  p.name, 
		CASE WHEN p.type IN ('G','U') THEN 
			'CREATE LOGIN ' + QUOTENAME( p.name ) + ' FROM WINDOWS WITH DEFAULT_DATABASE = [' + p.default_database_name + ']'
			+(CASE l.denylogin WHEN 1 THEN '; DENY CONNECT SQL TO [' +p.name+']' WHEN 0 THEN ' ' ELSE NULL END ) 
			+(CASE l.hasaccess WHEN 1 THEN ' '  WHEN 0 THEN '; REVOKE CONNECT SQL TO ['+p.name+']'  ELSE NULL END)
			+(CASE p.is_disabled WHEN 1 THEN '; ALTER LOGIN [' + QUOTENAME( p.name ) + '] DISABLE'  WHEN 0 THEN ' '  ELSE NULL END)
		ELSE 
			'CREATE LOGIN ' + QUOTENAME( p.name ) + ' WITH PASSWORD = ' + dbo.fn_hexadecimal(CAST( LOGINPROPERTY( p.name, 'PasswordHash' ) AS varbinary (256) )) + ' HASHED, SID = ' + dbo.fn_hexadecimal(p.sid) + ', DEFAULT_DATABASE = [' + p.default_database_name + ']' 
			+(Select CASE is_policy_checked WHEN 1 THEN ',CHECK_POLICY = ON' WHEN 0 THEN ',CHECK_POLICY = OFF' ELSE NULL END FROM sys.sql_logins WHERE name = p.name) 
			+(Select CASE is_expiration_checked WHEN 1 THEN ', CHECK_EXPIRATION = ON' WHEN 0 THEN ', CHECK_EXPIRATION = OFF' ELSE NULL END FROM sys.sql_logins WHERE name = p.name) 
			+(CASE l.denylogin WHEN 1 THEN '; DENY CONNECT SQL TO ' +QUOTENAME( p.name ) WHEN 0 THEN ' ' ELSE NULL END ) 
			+(CASE l.hasaccess WHEN 1 THEN ' '  WHEN 0 THEN '; REVOKE CONNECT SQL TO '+QUOTENAME( p.name ) ELSE NULL END)
			+(CASE p.is_disabled WHEN 1 THEN '; ALTER LOGIN ' + QUOTENAME( p.name ) + ' DISABLE'  WHEN 0 THEN ' '  ELSE NULL END)
				  END CScript,
		--=======================
		CASE WHEN p.type IN ('G','U') THEN 
			'ALTER LOGIN ' + QUOTENAME( p.name ) + '  WITH DEFAULT_DATABASE = [' + p.default_database_name + ']'
			+(CASE l.denylogin WHEN 1 THEN '; DENY CONNECT SQL TO '+QUOTENAME( p.name ) WHEN 0 THEN ' ' ELSE NULL END ) 
			+(CASE l.hasaccess WHEN 1 THEN ' '  WHEN 0 THEN '; REVOKE CONNECT SQL TO '+QUOTENAME( p.name )  ELSE NULL END)
			+(CASE p.is_disabled WHEN 1 THEN '; ALTER LOGIN ' + QUOTENAME( p.name ) + ' DISABLE'  WHEN 0 THEN ' '  ELSE NULL END)
		ELSE 
			'ALTER LOGIN ' + QUOTENAME( p.name ) + ' WITH PASSWORD = ' + dbo.fn_hexadecimal(CAST( LOGINPROPERTY( p.name, 'PasswordHash' ) AS varbinary (256) )) + ' HASHED , DEFAULT_DATABASE = [' + p.default_database_name + ']' 
			+(Select CASE is_policy_checked WHEN 1 THEN ',CHECK_POLICY = ON' WHEN 0 THEN ',CHECK_POLICY = OFF' ELSE NULL END FROM sys.sql_logins WHERE name = p.name) 
			+(Select CASE is_expiration_checked WHEN 1 THEN ', CHECK_EXPIRATION = ON' WHEN 0 THEN ', CHECK_EXPIRATION = OFF' ELSE NULL END FROM sys.sql_logins WHERE name = p.name) 
			+(CASE l.denylogin WHEN 1 THEN '; DENY CONNECT SQL TO '+QUOTENAME( p.name )  WHEN 0 THEN ' ' ELSE NULL END ) 
			+(CASE l.hasaccess WHEN 1 THEN ' '  WHEN 0 THEN '; REVOKE CONNECT SQL TO '+QUOTENAME( p.name )  ELSE NULL END)
			+(CASE p.is_disabled WHEN 1 THEN '; ALTER LOGIN ' + QUOTENAME( p.name ) + ' DISABLE'  WHEN 0 THEN ' '  ELSE NULL END)
				  END AScript 
		FROM 
		sys.server_principals p LEFT JOIN sys.syslogins l
		ON ( l.name = p.name ) WHERE p.type IN ( 'S', 'G', 'U' ) AND p.name <> 'sa' AND p.name NOT LIKE '%#%'
		 
	END
ELSE --- #P 
	BEGIN
		DECLARE @AGLreplica nvarchar(256)
		SELECT  @AGLreplica = hags.primary_replica 
		FROM 
			sys.dm_hadr_availability_group_states hags
			INNER JOIN sys.availability_groups ag ON ag.group_id = hags.group_id
		WHERE
			ag.name = 'NAG-1DE1P-ORKA';

		IF(@AGLreplica <> @@SERVERNAME) --2X
			BEGIN
				IF(@AGLreplica = 'USV-101-SQLP\DE1P')
						BEGIN
							INSERT INTO #tmpLoginTable
							SELECT *  FROM [USV-101-SQLP\DE1P].master.dbo.agLoginTable
						END
				ELSE IF(@AGLreplica = 'USV-102-SQLP\DE1P')
						BEGIN
							INSERT INTO #tmpLoginTable
							SELECT *  FROM [USV-102-SQLP\DE1P].master.dbo.agLoginTable
						END
				ELSE IF(@AGLreplica = 'KSV-101-SQLP\DE1P')
						BEGIN
							INSERT INTO #tmpLoginTable
							SELECT *  FROM [KSV-101-SQLP\DE1P].master.dbo.agLoginTable
						END						
			END

		SELECT * FROM #tmpLoginTable
	END
 
DECLARE @scriptC nvarchar(max)
DECLARE @scriptA nvarchar(max)
DECLARE @login nvarchar(256)
DECLARE @counter int
DECLARE @totalCount int
SELECT @totalCount=COUNT(1) FROM #tmpLoginTable
SET @counter = 1
While(@totalCount>=@counter)
		BEGIN
			SELECT TOP 1 @scriptC=CScript,@scriptA=AScript, @login=Loginname  FROM #tmpLoginTable

			IF NOT EXISTS(select * FROM sys.syslogins WHERE name = @login)
				BEGIN
					EXEC(@scriptC)
		END
		-----------
	ELSE
		BEGIN
			EXEC(@scriptA)
		END

	DELETE #tmpLoginTable WHERE Loginname = @login
	SET @counter +=1
END 

GO


