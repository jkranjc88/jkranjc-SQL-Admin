SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
DECLARE @StringToExecute NVARCHAR(4000), @TableName NVARCHAR(100);



/* ---------------------------------------- */
/* BEGIN SECTION: Backup throughput history */
/* ---------------------------------------- */

/* Azure SQL DB: no direct access to msdb */
IF SERVERPROPERTY('EngineEdition') IN (5, 6, 7)
    SELECT NULL AS Azure WHERE 1 = 2;
ELSE
    BEGIN
    SET @StringToExecute = N'
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	SELECT @@SERVERNAME AS [Server Name] ,
			YEAR(backup_finish_date) AS [Backup Year] ,
			MONTH(backup_finish_date) AS [Backup Month] ,
			CAST(AVG(( backup_size / ( DATEDIFF(ss, bset.backup_start_date, bset.backup_finish_date) ) / 1048576 )) AS INT) AS [Avg MB/Sec] ,
			CAST(MIN(( backup_size / ( DATEDIFF(ss, bset.backup_start_date, bset.backup_finish_date) ) / 1048576 )) AS INT) AS [Min MB/Sec] ,
			CAST(MAX(( backup_size / ( DATEDIFF(ss, bset.backup_start_date, bset.backup_finish_date) ) / 1048576 )) AS INT) AS [Max MB/Sec]
		FROM msdb.dbo.backupset bset
		WHERE bset.type = ''D'' /* full backups only */
			AND bset.backup_size > 5368709120 /* 5GB or larger */
			AND DATEDIFF(ss, bset.backup_start_date, bset.backup_finish_date) > 1 /* backups lasting over a second */
		GROUP BY YEAR(backup_finish_date) ,
			MONTH(backup_finish_date)
		ORDER BY @@SERVERNAME ,
			YEAR(backup_finish_date) DESC ,
			MONTH(backup_finish_date) DESC;';
    EXEC(@StringToExecute);
    END



/* --------------------------------------- */
/* BEGIN SECTION: Data Loss Risks - Top 50 */
/* --------------------------------------- */

/* Azure SQL DB: no direct access to msdb */
IF SERVERPROPERTY('EngineEdition') IN (5, 6, 7)
    SELECT NULL AS Azure WHERE 1 = 2;
ELSE
    BEGIN
    SET @StringToExecute = N'
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	CREATE TABLE #backupset (backup_set_id INT, database_name NVARCHAR(128), backup_finish_date DATETIME, type CHAR(1), next_backup_finish_date DATETIME);
	INSERT INTO #backupset (backup_set_id, database_name, backup_finish_date, type)
	  SELECT backup_set_id, database_name, backup_finish_date, type
	  FROM msdb.dbo.backupset WITH (NOLOCK)
	  WHERE backup_finish_date >= DATEADD(dd, -14, GETDATE())
	  AND database_name NOT IN (''master'', ''model'', ''msdb'');
	CREATE CLUSTERED INDEX CL_database_name_backup_finish_date ON #backupset (database_name, backup_finish_date);

	UPDATE #backupset
	SET next_backup_finish_date = (SELECT TOP 1 backup_finish_date FROM #backupset bsNext WHERE bs.database_name = bsNext.database_name AND bs.backup_finish_date < bsNext.backup_finish_date ORDER BY bsNext.backup_finish_date)
	FROM #backupset bs;

	SELECT bs1.database_name AS [Database Name], MAX(DATEDIFF(mi, bs1.backup_finish_date, bs1.next_backup_finish_date)) AS [Max Minutes of Data Loss]
	  FROM #backupset bs1
	  GROUP BY bs1.database_name
	  ORDER BY bs1.database_name

	DROP TABLE #backupset;';
    EXEC(@StringToExecute);
    END


/* --------------------------------------- */
/* BEGIN SECTION: Availability Groups   */
/* --------------------------------------- */
	
	IF 4 = (SELECT COUNT(*) FROM sys.all_objects WHERE name IN ('availability_replicas','availability_groups','availability_databases_cluster','dm_hadr_database_replica_states'))
	    AND EXISTS (SELECT * FROM sys.all_columns c INNER JOIN sys.all_objects o ON c.object_id = o.object_id WHERE c.name = 'is_primary_replica' AND o.name = 'dm_hadr_database_replica_states')
		BEGIN
		SET @StringToExecute = 'SELECT 
					ag.name AS ag_name,  
					s.is_primary_replica, 
					r.replica_server_name,
		            r.availability_mode_desc,
		            r.failover_mode_desc,
					s.synchronization_state_desc, 
					s.synchronization_health_desc,
		            c.database_name,
		            s.suspend_reason_desc,
		            s.last_received_time,
		            s.last_hardened_time,
		            s.last_redone_time,
		            s.last_commit_time,
		            s.log_send_queue_size,
		            s.log_send_rate,
		            s.redo_queue_size,
		            s.redo_rate,
		            ag.failure_condition_level,
		            ag.health_check_timeout,
		            r.session_timeout,
		            r.primary_role_allow_connections_desc,
		            r.secondary_role_allow_connections_desc
				FROM sys.dm_hadr_database_replica_states s
				JOIN sys.availability_databases_cluster c
					ON s.group_id = c.group_id AND 
					   s.group_database_id = c.group_database_id
				JOIN sys.availability_groups ag
					ON ag.group_id = s.group_id
				JOIN sys.availability_replicas r
					ON s.group_id = r.group_id AND 
					   s.replica_id = r.replica_id
		        ORDER BY 1, 2 DESC, 4 DESC, 3'
	        EXEC(@StringToExecute);
	    END
	ELSE IF 4 = (SELECT COUNT(*) FROM sys.all_objects WHERE name IN ('availability_replicas','availability_groups','availability_databases_cluster','dm_hadr_database_replica_states'))
		BEGIN
		SELECT 
					ag.name AS ag_name,  
					NULL AS is_primary_replica, 
					r.replica_server_name,
		            r.availability_mode_desc,
		            r.failover_mode_desc,
					s.synchronization_state_desc, 
					s.synchronization_health_desc,
		            c.database_name,
		            s.suspend_reason_desc,
		            s.last_received_time,
		            s.last_hardened_time,
		            s.last_redone_time,
		            s.last_commit_time,
		            s.log_send_queue_size,
		            s.log_send_rate,
		            s.redo_queue_size,
		            s.redo_rate,
		            ag.failure_condition_level,
		            ag.health_check_timeout,
		            r.session_timeout,
		            r.primary_role_allow_connections_desc,
		            r.secondary_role_allow_connections_desc
				FROM sys.dm_hadr_database_replica_states s
				JOIN sys.availability_databases_cluster c
					ON s.group_id = c.group_id AND 
					   s.group_database_id = c.group_database_id
				JOIN sys.availability_groups ag
					ON ag.group_id = s.group_id
				JOIN sys.availability_replicas r
					ON s.group_id = r.group_id AND 
					   s.replica_id = r.replica_id
		        ORDER BY 1, 2 DESC, 4 DESC, 3
	    END
	ELSE
	    BEGIN
		SELECT 
					NULL AS ag_name,  
					NULL AS is_primary_replica, 
					NULL AS replica_server_name,
		            NULL AS availability_mode_desc,
		            NULL AS failover_mode_desc,
					NULL AS synchronization_state_desc, 
					NULL AS synchronization_health_desc,
		            NULL AS database_name,
		            NULL AS suspend_reason_desc,
		            NULL AS last_received_time,
		            NULL AS last_hardened_time,
		            NULL AS last_redone_time,
		            NULL AS last_commit_time,
		            NULL AS log_send_queue_size,
		            NULL AS log_send_rate,
		            NULL AS redo_queue_size,
		            NULL AS redo_rate,
		            NULL AS failure_condition_level,
		            NULL AS health_check_timeout,
		            NULL AS session_timeout,
		            NULL AS primary_role_allow_connections_desc,
		            NULL AS secondary_role_allow_connections_desc
				WHERE 1 = 2
		END
	
/* --------------------------------------- */
/* END SECTION: Availability Groups   */
/* --------------------------------------- */
