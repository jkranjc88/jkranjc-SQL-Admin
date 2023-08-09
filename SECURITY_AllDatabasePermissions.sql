DECLARE @DatabaseName VARCHAR(50);
DECLARE @SqlCommand NVARCHAR(MAX);
DECLARE @DatabaseUserName VARCHAR(50); -- ='user'
DECLARE @LoginName VARCHAR(50); -- ='login'

CREATE TABLE #TEMP_OVERVIEW
(
  DatabaseName     VARCHAR(128)  NOT NULL
, UserType         VARCHAR(13)   NULL
, DatabaseUserName NVARCHAR(128) NOT NULL
, LoginName        NVARCHAR(128) NULL
, Role             NVARCHAR(128) NULL
, PermissionType   NVARCHAR(128) NULL
, PermissionState  NVARCHAR(60)  NULL
, ObjectType       NVARCHAR(60)  NULL
, [Schema]         sys.sysname   NULL
, ObjectName       NVARCHAR(128) NULL
, ColumnName       sys.sysname   NULL
);

DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
      name
FROM  master.sys.databases
WHERE name NOT IN ('master', 'msdb', 'model', 'tempdb')
      AND state_desc = 'online';

OPEN db_cursor;

FETCH NEXT FROM db_cursor
INTO
  @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN
  SELECT
    @SqlCommand = 'USE ' + @DatabaseName + ';' + '
INSERT INTO #TEMP_OVERVIEW
SELECT '''+ @DatabaseName + N''', t.*
FROM ( SELECT [UserType] = CASE princ.[type] 
WHEN ''S'' THEN ''SQL User'' 
WHEN ''U'' THEN ''Windows User''
WHEN ''G'' THEN ''Windows Group''
END,[DatabaseUserName] = princ.[name],
[LoginName]        = ulogin.[name],
[Role]             = NULL,
[PermissionType]   = perm.[permission_name],
[PermissionState]  = perm.[state_desc],
[ObjectType] = CASE perm.[class]
WHEN 1 THEN obj.[type_desc]
ELSE perm.[class_desc]
END,
[Schema] = objschem.[name],
[ObjectName] = CASE perm.[class]
WHEN 3 THEN permschem.[name] 
WHEN 4 THEN imp.[name]
ELSE OBJECT_NAME(perm.[major_id])
END,
[ColumnName] = col.[name]
FROM
sys.database_principals princ
LEFT JOIN sys.server_principals ulogin ON ulogin.[sid] = princ.[sid]
LEFT JOIN sys.database_permissions perm ON perm.[grantee_principal_id] = princ.[principal_id]
LEFT JOIN sys.schemas permschem ON permschem.[schema_id] = perm.[major_id]
LEFT JOIN sys.objects obj ON obj.[object_id] = perm.[major_id]
LEFT JOIN sys.schemas objschem  ON objschem.[schema_id] = obj.[schema_id]
LEFT JOIN sys.columns col ON col.[object_id] = perm.[major_id]
AND col.[column_id] = perm.[minor_id]
LEFT JOIN sys.database_principals imp ON imp.[principal_id] = perm.[major_id]
WHERE
princ.[type] IN (''S'',''U'',''G'')
AND princ.[name] NOT IN (''sys'', ''INFORMATION_SCHEMA'')
UNION
SELECT
[UserType] = CASE membprinc.[type]
WHEN ''S'' THEN ''SQL User''
WHEN ''U'' THEN ''Windows User''
WHEN ''G'' THEN ''Windows Group''
END,
[DatabaseUserName] = membprinc.[name],
[LoginName] = ulogin.[name],
[Role] = rp.[name],
[PermissionType] = perm.[permission_name],
[PermissionState] = perm.[state_desc],
[ObjectType] = CASE perm.[class]
WHEN 1 THEN obj.[type_desc]
ELSE perm.[class_desc]
END,
[Schema] = objschem.[name],
[ObjectName] = CASE perm.[class]
WHEN 3 THEN permschem.[name]
WHEN 4 THEN imp.[name]
ELSE OBJECT_NAME(perm.[major_id])
END,
[ColumnName] = col.[name]
FROM
sys.database_role_members members
JOIN sys.database_principals  rp ON rp.[principal_id] = members.[role_principal_id]
JOIN sys.database_principals membprinc ON membprinc.[principal_id] = members.[member_principal_id]
LEFT JOIN sys.server_principals ulogin ON ulogin.[sid] = membprinc.[sid]
LEFT JOIN sys.database_permissions perm ON perm.[grantee_principal_id] = rp.[principal_id]
LEFT JOIN sys.schemas permschem ON permschem.[schema_id] = perm.[major_id]
LEFT JOIN sys.objects obj ON obj.[object_id] = perm.[major_id]
LEFT JOIN sys.schemas objschem ON objschem.[schema_id] = obj.[schema_id]
LEFT JOIN sys.columns col ON col.[object_id] = perm.[major_id] AND col.[column_id] = perm.[minor_id]
LEFT JOIN sys.database_principals imp ON imp.[principal_id] = perm.[major_id]
WHERE
membprinc.[type] IN (''S'',''U'',''G'')
AND membprinc.[name] NOT IN (''sys'', ''INFORMATION_SCHEMA'')
UNION
SELECT
[UserType] = ''{All Users}'',
[DatabaseUserName] = ''{All Users}'',
[LoginName] = ''{All Users}'',
[Role] = rp.[name],
[PermissionType] = perm.[permission_name],
[PermissionState] = perm.[state_desc],
[ObjectType] = CASE perm.[class]
WHEN 1 THEN obj.[type_desc]
ELSE perm.[class_desc]
END,
[Schema] = objschem.[name],
[ObjectName] = CASE perm.[class]
WHEN 3 THEN permschem.[name]
WHEN 4 THEN imp.[name]
ELSE OBJECT_NAME(perm.[major_id])
END,
[ColumnName] = col.[name]
FROM sys.database_principals rp
LEFT JOIN sys.database_permissions perm ON perm.[grantee_principal_id] = rp.[principal_id]
LEFT JOIN sys.schemas permschem ON permschem.[schema_id] = perm.[major_id]
JOIN sys.objects obj ON obj.[object_id] = perm.[major_id]
LEFT JOIN sys.schemas objschem  ON objschem.[schema_id] = obj.[schema_id]
LEFT JOIN sys.columns col ON col.[object_id] = perm.[major_id]
AND col.[column_id] = perm.[minor_id]
LEFT JOIN sys.database_principals imp ON imp.[principal_id] = perm.[major_id]
WHERE rp.[type] = ''R''
AND rp.[name] = ''public''
AND obj.[is_ms_shipped] = 0
) t;'
 print @sqlcommand
  EXEC sp_executesql @SqlCommand;

  FETCH NEXT FROM db_cursor
  INTO
    @DatabaseName;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

SELECT *
FROM #TEMP_OVERVIEW
--WHERE DatabaseUserName = @DatabaseUserName
--AND LoginName = @LoginName;

DROP TABLE #TEMP_OVERVIEW;
