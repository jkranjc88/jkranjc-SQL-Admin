SELECT  
   CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server, 
   bs.database_name,
   db.database_id,
   MAX(bs.backup_finish_date) AS last_db_backup_date
FROM 
   msdb.dbo.backupmediafamily  bf
   INNER JOIN msdb.dbo.backupset  bs
	ON bf.media_set_id = bs.media_set_id
	INNER JOIN master.sys.databases db
	ON db.name = bs.database_name
WHERE bs.type = 'D' 
GROUP BY 
   bs.database_name , db.database_id
ORDER BY  
   3