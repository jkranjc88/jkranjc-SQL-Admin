DECLARE @StringToExecute NVARCHAR(4000), @TableName NVARCHAR(100);

/* Azure SQL DB: no direct access to tempdb, so we have to work in the current database */
IF EXISTS(SELECT * FROM sys.all_objects WHERE name = 'master_files')
    SET @TableName = N' sys.master_files f ON a.file_id = f.file_id AND a.database_id = f.database_id ';
ELSE
    SET @TableName = N' sys.database_files f ON a.file_id = f.file_id AND a.database_id = DB_ID() ';



/* -------------------------------------------------- */
/* BEGIN SECTION: Storage throughput by database file */
/* -------------------------------------------------- */
SET @StringToExecute = N' 
	SELECT  DB_NAME(a.database_id) AS [Database Name] ,
        f.name + N'' ['' + f.type_desc COLLATE SQL_Latin1_General_CP1_CI_AS + N'']'' AS [Logical File Name] ,
        UPPER(SUBSTRING(f.physical_name, 1, 2)) AS [Drive] ,
        CAST(( ( a.size_on_disk_bytes / 1024.0 ) / (1024.0*1024.0) ) AS DECIMAL(9,2)) AS [Size (GB)] ,
        a.io_stall_read_ms AS [Total IO Read Stall] ,
        a.num_of_reads AS [Total Reads] ,
        CASE WHEN a.num_of_bytes_read > 0 
            THEN CAST(a.num_of_bytes_read/1024.0/1024.0/1024.0 AS NUMERIC(23,1))
            ELSE 0 
        END AS [GB Read],
        CAST(a.io_stall_read_ms / ( 1.0 * a.num_of_reads ) AS INT) AS [Avg Read Stall (ms)] ,
        a.io_stall_write_ms AS [Total IO Write Stall] ,
        a.num_of_writes [Total Writes] ,
        CASE WHEN a.num_of_bytes_written > 0 
            THEN CAST(a.num_of_bytes_written/1024.0/1024.0/1024.0 AS NUMERIC(23,1))
            ELSE 0 
        END AS [GB Written],
        CAST(a.io_stall_write_ms / ( 1.0 * a.num_of_writes ) AS INT) AS [Avg Write Stall (ms)] ,
        f.physical_name AS [Physical File Name],
        GETDATE() AS [Sample Time],
        f.type_desc
	FROM    sys.dm_io_virtual_file_stats(NULL, NULL) AS a
			INNER JOIN ' + @TableName + N'
	WHERE   a.num_of_reads > 0
			AND a.num_of_writes > 0
	ORDER BY  CAST(a.io_stall_read_ms / ( 1.0 * a.num_of_reads ) AS INT) DESC;';
EXEC(@StringToExecute);


/* ------------------------------------------------ */
/* END SECTION: Storage throughput by database file */
/* ------------------------------------------------ */


/* ------------------------------------------------- */
/* BEGIN SECTION: Storage throughput by drive letter */
/* ------------------------------------------------- */

SET @StringToExecute = N'
	SELECT  UPPER(SUBSTRING(f.physical_name, 1, 2)) AS [Drive] ,
			SUM(a.io_stall_read_ms) AS io_stall_read_ms ,
			SUM(a.num_of_reads) AS num_of_reads ,
			CAST(SUM(a.num_of_bytes_read)/1024.0/1024.0/1024.0 AS NUMERIC(23,1)) AS [GB Read],
			CASE WHEN SUM(a.num_of_reads) > 0
			  THEN CAST(SUM(a.io_stall_read_ms) / ( 1.0 * SUM(a.num_of_reads) ) AS INT) 
			  ELSE CAST(0 AS INT) END AS [Avg Read Stall (ms)] ,
			SUM(a.io_stall_write_ms) AS io_stall_write_ms ,
			SUM(a.num_of_writes) AS num_of_writes ,
			CAST(SUM(a.num_of_bytes_written)/1024.0/1024.0/1024.0 AS NUMERIC(23,1)) AS [GB Written],
			CASE WHEN SUM(a.num_of_writes) > 0
			  THEN CAST(SUM(a.io_stall_write_ms) / ( 1.0 * SUM(a.num_of_writes) ) AS INT) 
			  ELSE CAST(0 AS INT) END AS [Avg Write Stall (ms)]
	FROM    sys.dm_io_virtual_file_stats(NULL, NULL) a
			INNER JOIN ' + @TableName + N'
	GROUP BY UPPER(SUBSTRING(f.physical_name, 1, 2))
	ORDER BY 4 DESC;';

EXEC(@StringToExecute);	

/* ----------------------------------------------- */
/* END SECTION: Storage throughput by drive letter */
/* ----------------------------------------------- */