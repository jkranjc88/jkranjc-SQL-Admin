; WITH [Hours] ([Hour]) AS
(
SELECT TOP 24 ROW_NUMBER() OVER (ORDER BY [object_id]) AS [Hour]
FROM sys.objects
ORDER BY [object_id]
)
SELECT 
	CONVERT(CHAR(100), SERVERPROPERTY('Servername')) as "Server", 
	baks.database_name, 
	baks.backup_start_date,
	CASE
	WHEN H.HOUR IS NULL THEN 0 ELSE H.HOUR
	END AS Hrs,
	cast(baks.backup_start_date as date) "StartDate",
	cast(baks.backup_start_date as time) "StartTime",
	baks.backup_finish_date, 
	datediff(mi, baks.backup_start_date , baks.backup_finish_date) as MinutesToFinish,
	--baks.expiration_date, 
	CASE baks."type" 
		WHEN 'D' THEN 'Database' 
		WHEN 'L' THEN 'Log' 
	END as backup_type, 
	cast(baks.backup_size/1024/1024 as decimal(18,2)) BackupSizeMB
	--bakf.logical_device_name, 
	--bakf.physical_device_name, 
	--baks.name backupset_name, 
	--baks.description 
FROM msdb.dbo.backupmediafamily bakf
INNER JOIN msdb.dbo.backupset baks 
	ON bakf.media_set_id =baks.media_set_id
FULL OUTER JOIN [Hours] h
	ON datepart(hh, baks.backup_start_date) = h.Hour
WHERE
-- Zadnjih 7 dni
(CONVERT(datetime, baks.backup_start_date, 102) >= GETDATE() - 14) 
-- Ime baze - zakomentiraj za vse
--and baks.database_name = 'Horizon'
-- Samo Log
--and baks."type" = 'L'
-- Vsi ki so trajali dalje kot 1 minuto
--and datediff(mi, msdb.dbo.backupset.backup_start_date , msdb.dbo.backupset.backup_finish_date) > 0
ORDER BY 
baks.database_name, 
baks.backup_finish_date 
