/* ------------------------------------------------ */
/* BEGIN SECTION: Database file and log allocations */
/* ------------------------------------------------ */

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @sql NVARCHAR(MAX) ,
	@database_id INT,
	@databasename NVARCHAR(500) ,
	@counter INT ,
	@num_dbs INT;

/* We need some worktables.*/
CREATE TABLE #dbs
	(
		i INT IDENTITY ,
		[database_id] INT,
		[database name] NVARCHAR(500),
		recovery_model_desc NVARCHAR(60),
		vlf_count INT,
		dbcc_last_finished_successfully VARCHAR(50),
		backup_full_last_finished_successfully DATETIME,
		backup_log_last_finished_successfully DATETIME,
		buffer_pool_cached_gb NUMERIC(20, 2),
		buffer_pool_cached_empty_space_gb NUMERIC(20, 2),
		state_desc VARCHAR(50),
		compatibility_level TINYINT,
        secondary_role_allow_connections_desc NVARCHAR(50),
		edition NVARCHAR(50),
		service_objective NVARCHAR(50)
	)


DECLARE @spaceused TABLE
	(
		[database_id] INT ,
        [database name] NVARCHAR(500) ,
		[datafiles size GB] NUMERIC(20, 2) ,
		[datafiles percent allocated] NUMERIC(4, 1) ,
		[number of datafiles] INT ,
		[datafiles unallocated GB] NUMERIC(20, 2) ,
		[reserved GB] NUMERIC(20, 2) ,
		[lob reserved GB] NUMERIC(20, 2) ,
		[row overflow reserved GB] NUMERIC(20, 2) ,
		[datafiles reserved unused GB] NUMERIC(20, 2) ,
		[number fulltext catalogs] INT ,
		[fulltext catalog size mb] NUMERIC(20, 2) ,
		[number of log files] INT
	)

DECLARE @logspaceused TABLE
	(
		[database_id] INT ,
		[database name] NVARCHAR(500) ,
		[logfiles size MB] NUMERIC(20, 1) ,
		[log space used percent] NUMERIC(20, 1) ,
		[status] INT
	)

DECLARE @memory_analysis TABLE
	(
		[measure_name] NVARCHAR(200) ,
		[measure_value] NUMERIC(20, 1),
		[priority] INT
	)

DECLARE @log_info_2008 TABLE (
	fileid TINYINT ,
	file_size BIGINT ,
	start_offset BIGINT ,
	FSeqNo INT ,
	[status] TINYINT ,
	parity TINYINT ,
	create_lsn NUMERIC(25, 0) );

DECLARE @log_info_2012 TABLE (
	recoveryunitid INT,
	fileid TINYINT ,
	file_size BIGINT ,
	start_offset BIGINT ,
	FSeqNo INT ,
	[status] TINYINT ,
	parity TINYINT ,
	create_lsn NUMERIC(25, 0) );




/* How much memory is SQL Server aiming to use right now? */
INSERT @memory_analysis (measure_name, measure_value, priority)
SELECT  TOP 1 'Target Server Memory (GB)', cntr_value / 1024.0 / 1024, 101
FROM    sys.dm_os_performance_counters
WHERE   OBJECT_NAME LIKE N'%Memory Manager%'
AND counter_name LIKE 'Target Server Memory (KB)%'
ORDER BY cntr_value DESC

/* How much memory is SQL Server actually using? This may be lower. */
INSERT @memory_analysis (measure_name, measure_value, priority)
SELECT  TOP 1 'Total Server Memory (GB)', cntr_value / 1024.0 / 1024, 102
FROM    sys.dm_os_performance_counters
WHERE   OBJECT_NAME LIKE N'%Memory Manager%'
AND counter_name LIKE 'Total Server Memory (KB)%'
ORDER BY cntr_value DESC

/* Build the list of databases. */
INSERT #dbs (database_id, [database name], recovery_model_desc, state_desc, compatibility_level)
		SELECT database_id, name, recovery_model_desc, state_desc, compatibility_level
			FROM sys.databases;


/* Amazon RDS doesn't support this part */
IF LEFT(CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS VARCHAR(8000)), 8) = 'EC2AMAZ-'
   AND LEFT(CAST(SERVERPROPERTY('MachineName') AS VARCHAR(8000)), 8) = 'EC2AMAZ-'
   AND LEFT(CAST(SERVERPROPERTY('ServerName') AS VARCHAR(8000)), 8) = 'EC2AMAZ-'
BEGIN
	DELETE #dbs WHERE [database name] IN ('master', 'model', 'msdb', 'tempdb', 'rdsadmin');
END

/* Update databases in an Availability Group */
IF EXISTS (SELECT * FROM sys.all_objects o INNER JOIN sys.all_columns c ON o.object_id = c.object_id AND o.name = 'dm_hadr_availability_replica_states' AND c.name = 'role_desc')
    BEGIN
    SET @sql = N'UPDATE #dbs SET secondary_role_allow_connections_desc = N''NO''
        WHERE [database name] IN (
                SELECT d.name 
                FROM sys.dm_hadr_availability_replica_states rs
                INNER JOIN sys.databases d ON rs.replica_id = d.replica_id
                INNER JOIN sys.availability_replicas r ON rs.replica_id = r.replica_id
                WHERE rs.role_desc = ''SECONDARY''
                AND r.secondary_role_allow_connections_desc = ''NO'');'
    EXEC sp_executesql @sql;
    END

INSERT @logspaceused
		( [database name] ,
			[logfiles size MB] ,
			[log space used percent] ,
			status )
		EXEC sp_executesql N'dbcc sqlperf(logspace)';

/* Fix Unicode database names */
UPDATE @logspaceused
    SET database_id = db.database_id
FROM @logspaceused lsu
  INNER JOIN #dbs db
			ON CAST(db.[database name] COLLATE DATABASE_DEFAULT AS VARCHAR(500)) = CAST(lsu.[database name] COLLATE DATABASE_DEFAULT AS VARCHAR(500))
  WHERE lsu.database_id IS NULL;

/* Get VLF counts */
DECLARE @SQLServerProductVersion NVARCHAR(128);
SET @SQLServerProductVersion = CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128));

SET NOCOUNT ON;

/* Amazon RDS doesn't support DBCC LOGINFO */
IF LEFT(CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS VARCHAR(8000)), 8) <> 'EC2AMAZ-'
   AND LEFT(CAST(SERVERPROPERTY('MachineName') AS VARCHAR(8000)), 8) <> 'EC2AMAZ-'
   AND LEFT(CAST(SERVERPROPERTY('ServerName') AS VARCHAR(8000)), 8) <> 'EC2AMAZ-'
BEGIN
	DECLARE csr CURSOR FAST_FORWARD READ_ONLY
	FOR
	SELECT database_id, [database name] 
        FROM #dbs 
        WHERE state_desc = 'ONLINE'
        AND COALESCE(secondary_role_allow_connections_desc, N'OK') <> N'NO';

	OPEN csr;
	FETCH NEXT FROM csr INTO @database_id, @databasename;

	WHILE ( @@fetch_status <> -1 )
		BEGIN

			/* Get VLF counts */
			SET @sql = N'USE ' + QUOTENAME(@databasename) + '; DBCC loginfo () ';

			IF (SELECT LEFT(@SQLServerProductVersion,
				CHARINDEX('.',@SQLServerProductVersion,0)-1
				)) >= 11
				BEGIN
						INSERT INTO @log_info_2012
						EXEC sp_executesql @sql;
				END
			ELSE
				BEGIN
						INSERT INTO @log_info_2008
						EXEC sp_executesql @sql;
				END

			UPDATE #dbs
				SET vlf_count = @@rowcount
				WHERE database_id = @database_id

			DELETE FROM @log_info_2008;
			DELETE FROM @log_info_2012;


			/* Get database size */
			SELECT @sql = N'
				USE ' + QUOTENAME(@databasename) + N';
				SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
				DECLARE @datasize numeric(20,1),
					@reservedpages bigint,
					@lobreservedpages bigint,
					@rowoverflowreservedpages bigint,
					@usedpages bigint,
					@numberdatafiles int,
					@numberlogfiles int,
					@numberfulltextcatalogs int,
					@fulltextcatalogsMB numeric(20,2);

				SELECT  @datasize=SUM(CASE WHEN type = 0 THEN CAST(size AS BIGINT)
									ELSE CAST(0 AS BIGINT)
							END),
						@numberdatafiles=SUM(CASE WHEN type = 0 THEN 1
									ELSE 0
							END) ,
						@numberlogfiles=SUM(CASE WHEN type = 1 THEN 1
									ELSE 0
							END)
				FROM sys.database_files;

				SELECT @reservedpages=SUM(reserved_page_count),
					@usedpages=SUM(used_page_count),
					@lobreservedpages=SUM(lob_reserved_page_count),
					@rowoverflowreservedpages=sum(row_overflow_reserved_page_count)
				FROM sys.dm_db_partition_stats

				/* We can count the catalogs for all DBs from anywhere,
				but to get the size we have to query from each one.*/
				SELECT
					@numberfulltextcatalogs=COUNT(*) ,
					@fulltextcatalogsMB=SUM(FULLTEXTCATALOGPROPERTY(name, ''indexsize''))
				FROM sys.dm_fts_active_catalogs
				where database_id=db_id();

				select db_id() AS [database_id],
					' + QUOTENAME(@databasename, '''') + N' AS [database name],
					@datasize * 8192./1048576./1024. AS [datafiles size GB],
					CASE WHEN @reservedpages >= @datasize THEN 100 ELSE CAST(100 * @reservedpages/(1.0 * @datasize) AS NUMERIC(4,1)) END  AS [datafiles percent allocated],
					@numberdatafiles AS [number of datafiles],
					case
						when @datasize >= @reservedpages
							then (@datasize - @reservedpages) * 8192 / 1048576./1024.
							else 0
						END AS [datafiles unallocated GB] ,
					@reservedpages * 8192/1024./1024./1024. AS [reserved GB],
					@lobreservedpages * 8192/1024./1024./1024. AS [lob reserved GB ],
					@rowoverflowreservedpages * 8192/1024./1024./1024. AS [row overflow reserved GB],
					(@reservedpages - @usedpages) * 8192. / 1024./1024./1024. AS [datafiles reserved unused GB],
					@numberfulltextcatalogs AS [number fulltext catalogs],
					isnull(@fulltextcatalogsMB/1024.,0) AS [fulltext catalog size gb],
					@numberlogfiles AS [number of log files]
					;

				';
			INSERT @spaceused
					EXEC sp_executesql @sql;


			FETCH NEXT FROM csr INTO @database_id, @databasename;
		END

	CLOSE csr;
	DEALLOCATE csr;
END; /* Amazon RDS doesn't support DBCC LOGINFO */


/* Azure service level objectives */
IF EXISTS (SELECT * FROM sys.all_objects o INNER JOIN sys.all_columns c ON o.object_id = c.object_id AND o.name = 'database_service_objectives' AND c.name = 'edition')
    BEGIN
    SET @sql = N'UPDATE #dbs SET edition = obj.edition, service_objective = obj.service_objective
		FROM #dbs dbs
		LEFT OUTER JOIN sys.database_service_objectives obj ON dbs.database_id = obj.database_id;'
    EXEC sp_executesql @sql;
    END;


/*Retrieve data from #dbs*/
WITH Totals AS (SELECT 
		SUM(su.[datafiles size GB] ) AS data_size_gb, 
		SUM(dbs.buffer_pool_cached_gb) AS data_cached_gb,
		CONVERT(DECIMAL (18,2), (SUM([dbs].[buffer_pool_cached_gb]) / SUM([su].[datafiles size GB] + .01)) * 100) AS data_file_pct_cached,
		SUM([datafiles unallocated GB]) AS data_unallocated_gb,
		SUM(dbs.buffer_pool_cached_empty_space_gb) AS empty_space_in_cache_gb,
		SUM(su.[number of datafiles]) AS number_of_datafiles,
		SUM(su.[lob reserved GB]) AS lob_reserved_gb,
		SUM(CAST(lsu.[logfiles size MB] / 1024. AS NUMERIC(20, 1))) AS log_size_gb,
		SUM(su.[number of log files]) AS number_of_log_files
	FROM #dbs dbs
	    LEFT JOIN @spaceused su
		    ON dbs.[database_id] = su.[database_id]
		LEFT JOIN @logspaceused lsu
		    ON dbs.[database_id] = lsu.[database_id]
)
SELECT [Database Name] = dbs.[database name] ,
		CASE WHEN dbs.[database name] IN ('master', 'model', 'msdb', 'tempdb') THEN '(system database)'
			WHEN dbs.[database name] IN ('ReportServer', 'ReportServerTempDB') THEN '(reporting services)'
			WHEN dbs.[database name] IN ('SSIS_Configuration') THEN '(integration services)'
			ELSE ' ' END AS [Description],
		dbs.recovery_model_desc AS [Recovery Model],
		dbs.dbcc_last_finished_successfully AS [Last CHECKDB Date],
		su.[datafiles size GB] AS [Data Size GB],
		dbs.buffer_pool_cached_gb AS [Data Cached GB],
		CONVERT(DECIMAL (18,2), (dbs.[buffer_pool_cached_gb] / (su.[datafiles size GB] + .01)) * 100.) AS [Data File % Cached],
		su.[datafiles unallocated GB] AS [Data Unallocated GB] ,
		dbs.buffer_pool_cached_empty_space_gb [Empty Space In Cache GB],
		su.[datafiles percent allocated] AS [Data % Allocated] ,
		su.[number of datafiles] AS [# of Data Files],
		su.[lob reserved GB] AS [LOB Reserved GB] ,
		[Log Size (GB)] = CAST(lsu.[logfiles size MB] / 1024. AS NUMERIC(20, 1)) ,
		[Log % Allocated] = [log space used percent] ,
		su.[number of log files] AS [# of Log Files],
		dbs.vlf_count AS [VLF Count],
		dbs.state_desc AS [DB State],
		dbs.compatibility_level AS [Compat Level],
		dbs.edition,
		dbs.service_objective,
		db.*
	FROM #dbs dbs
	    LEFT JOIN @spaceused su
		    ON dbs.[database_id] = su.[database_id]
		LEFT JOIN @logspaceused lsu
		    ON dbs.[database_id] = lsu.[database_id]
		LEFT JOIN sys.databases db
			ON dbs.database_id = db.database_id
UNION ALL
	SELECT dbName = '_Total',
		NULL AS db_description,
		NULL AS recovery_model_desc,
		NULL AS dbcc_last_finished_successfully,
		t.data_size_gb,
		t.data_cached_gb,
		t.data_file_pct_cached,
		t.data_unallocated_gb,
		t.empty_space_in_cache_gb,
		NULL AS [datafiles percent allocated] ,
		t.number_of_datafiles,
		t.lob_reserved_gb,
		t.log_size_gb,
		NULL AS [logfile percent allocated],
		t.number_of_log_files,
		NULL AS [VLF Count],
		NULL AS state_desc,
		NULL AS [Compat Level],
		NULL AS edition,
		NULL AS service_objective,
		db.*
	FROM Totals t
		LEFT JOIN sys.databases db
			ON 1 = 0
	ORDER BY 1;	

DROP TABLE #dbs;


/* ---------------------------------------------- */
/* END SECTION: Database file and log allocations */
/* ---------------------------------------------- */



/* ------------------------------------------- */
/* BEGIN SECTION: Server memory vs cached data */
/* ------------------------------------------- */

/* How much data are we storing? */
INSERT INTO @memory_analysis (measure_name, measure_value, priority)
SELECT 'Data Stored (GB)', SUM([datafiles size GB]) - SUM(su.[datafiles unallocated GB]), 1
FROM @spaceused su;


/* How much physical memory does the box have? */
/* SQL Server 2012 and newer: */
IF EXISTS ( SELECT  *
			FROM    sys.all_objects o
					INNER JOIN sys.all_columns c ON o.object_id = c.object_id
			WHERE   o.name = 'dm_os_sys_info'
					AND c.name = 'physical_memory_kb' )
BEGIN
	SET @sql = 'SELECT ''Memory Installed GB'', CAST(ROUND((physical_memory_kb / 1024.0 / 1024), 1) AS BIGINT), 100
				FROM sys.dm_os_sys_info;'
	INSERT @memory_analysis
				EXEC sp_executesql @sql;
END

/* SQL Server 2008 and older: */
IF EXISTS ( SELECT  *
			FROM    sys.all_objects o
					INNER JOIN sys.all_columns c ON o.object_id = c.object_id
			WHERE   o.name = 'dm_os_sys_info'
					AND c.name = 'physical_memory_in_bytes' )
BEGIN
	SET @sql = 'SELECT ''Memory Installed (GB)'', CAST(ROUND((physical_memory_in_bytes / 1024.0 / 1024 / 1024), 1) AS BIGINT), 100
				FROM sys.dm_os_sys_info;'
	INSERT @memory_analysis
				EXEC sp_executesql @sql;
END



/* Putting target memory into perspective: */
INSERT @memory_analysis (measure_name, measure_value, priority)
SELECT 'Memory Usage as a Percent of Data Size', mMemory.measure_value / mData.measure_value * 100 , 103
FROM @memory_analysis mData
INNER JOIN @memory_analysis mMemory ON mMemory.measure_name = 'Total Server Memory (GB)'
WHERE mData.measure_name = 'Data Stored (GB)'
AND mData.measure_value > 0
AND mMemory.measure_value > 0




SELECT measure_name AS [Measure], measure_value AS [Value] FROM @memory_analysis ORDER BY priority;


/* ----------------------------------------- */
/* END SECTION: Server memory vs cached data */
/* ----------------------------------------- */

