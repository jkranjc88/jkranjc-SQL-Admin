/** REPORT **/

DECLARE @path NVARCHAR(260)

SELECT @path=path FROM sys.traces WHERE is_default = 1

SELECT TE.name AS EventName, DT.DatabaseName, DT.ApplicationName, 
DT.LoginName, COUNT(*) AS Quantity 
FROM dbo.fn_trace_gettable (@path,  DEFAULT) DT 
INNER JOIN sys.trace_events TE 
ON DT.EventClass = TE.trace_event_id 
GROUP BY TE.name , DT.DatabaseName , DT.ApplicationName, DT.LoginName 
ORDER BY TE.name, DT.DatabaseName , DT.ApplicationName, DT.LoginName


/** FILE GROWTH **/

DECLARE @path NVARCHAR(260)

SELECT @path=path FROM sys.traces WHERE is_default = 1

--Database: Data & Log File Auto Grow
SELECT DatabaseName, [FileName],
CASE EventClass WHEN 92 THEN 'Data File Auto Grow'   
 WHEN 93 THEN 'Log File Auto Grow'END AS EventClass,
Duration, StartTime, EndTime, SPID, ApplicationName, LoginName 
FROM sys.fn_trace_gettable(@path, DEFAULT)
WHERE EventClass IN (92,93)
ORDER BY StartTime DESC


/** FILE SHRINK **/

DECLARE @path NVARCHAR(260)

SELECT @path=path FROM sys.traces WHERE is_default = 1

--Database: Data & Log File Shrink
SELECT TextData, Duration, StartTime, EndTime, SPID, ApplicationName, LoginName  
FROM sys.fn_trace_gettable(@path, DEFAULT)
WHERE EventClass IN (116) AND TextData like 'DBCC%SHRINK%'
ORDER BY StartTime DESC


/** DBCC EXECUTES **/

DECLARE @path NVARCHAR(260)

SELECT @path=path FROM sys.traces WHERE is_default = 1

--Security Audit: Audit DBCC CHECKDB, DBCC CHECKTABLE, DBCC CHECKCATALOG,
--DBCC CHECKALLOC, DBCC CHECKFILEGROUP Events, and more.
SELECT TextData, Duration, StartTime, EndTime, SPID, ApplicationName, LoginName  
FROM sys.fn_trace_gettable(@path, DEFAULT)
WHERE EventClass IN (116) AND TextData like 'DBCC%CHECK%'
ORDER BY StartTime DESC


/** BACKUP EVENTS **/

DECLARE @path NVARCHAR(260)

SELECT @path=path FROM sys.traces WHERE is_default = 1

--Security Audit: Audit Backup Event
SELECT DatabaseName, TextData, Duration, StartTime, EndTime,
SPID, ApplicationName, LoginName   
FROM sys.fn_trace_gettable(@path, DEFAULT)
WHERE EventClass IN (115) and EventSubClass=1
ORDER BY StartTime DESC

/** RESTORE EVENTS **/

DECLARE @path NVARCHAR(260)

SELECT @path=path FROM sys.traces WHERE is_default = 1

--Security Audit: Audit Restore Event
SELECT TextData, Duration, StartTime, EndTime, SPID, ApplicationName, LoginName     
 FROM sys.fn_trace_gettable(@path, DEFAULT)
WHERE EventClass IN (115) and EventSubClass=2
ORDER BY StartTime DESC;

/** HASH SORT WARNING **/

DECLARE @path NVARCHAR(260)

SELECT @path=path FROM sys.traces WHERE is_default = 1

--Errors and Warnings: Hash Warning
SELECT TextData, Duration, StartTime, EndTime, SPID, ApplicationName, LoginName  
FROM sys.fn_trace_gettable(@path, DEFAULT)
WHERE EventClass IN (55)
ORDER BY StartTime DESC;

/** MISSING STATISTICS **/

DECLARE @path NVARCHAR(260)

SELECT @path=path FROM sys.traces WHERE is_default = 1

--Errors and Warnings: Missing Column Statistics
SELECT DatabaseName, TextData, Duration, StartTime, EndTime, SPID, ApplicationName, LoginName 
FROM sys.fn_trace_gettable(@path, DEFAULT)
WHERE  EventClass IN (79)
ORDER BY StartTime DESC;


/** MISSING JOIN PREDICATE **/

DECLARE @path NVARCHAR(260)

SELECT @path=path FROM sys.traces WHERE is_default = 1

--Errors and Warnings: Missing Join Predicate
SELECT DatabaseName,TextData, Duration, StartTime, EndTime, SPID, ApplicationName, LoginName  
FROM sys.fn_trace_gettable(@path, DEFAULT)
WHERE EventClass IN (80)
ORDER BY  StartTime DESC;


/** SORT WARNING **/

DECLARE @path NVARCHAR(260)

SELECT @path=path FROM sys.traces WHERE is_default = 1

--Errors and Warnings: Sort Warnings
SELECT DatabaseName, TextData, Duration, StartTime, EndTime, 
SPID, ApplicationName, LoginName   
FROM sys.fn_trace_gettable(@path, DEFAULT)
WHERE EventClass IN (69)
ORDER BY StartTime DESC;


/** ERRORLOG **/

DECLARE @path NVARCHAR(260)

SELECT @path=path FROM sys.traces WHERE is_default = 1

--Errors and Warnings: ErrorLog
SELECT TextData, Duration, StartTime, EndTime, SPID, ApplicationName, LoginName   
FROM sys.fn_trace_gettable(@path, DEFAULT)
WHERE EventClass IN (22)
ORDER BY StartTime DESC;


/** 
Adding and Finding SQL Server Auto Statistics Events 
The Default trace does not include information on Auto Statistics event, but you can add this event to be captured by using the sp_trace_setevent stored procedure. The trace event id is 58. It important to say that the information for this event can also be queried from the sys.dm_db_stats_properties DMF or Extended Events. Checking event details of Auto Statistics indicates automatic updating of index statistics that have occurred.
**/

DECLARE @path NVARCHAR(260)

SELECT @path=path FROM sys.traces WHERE is_default = 1

--Auto Stats, Indicates an automatic updating of index statistics has occurred.
SELECT TextData, ObjectID, ObjectName, IndexID, Duration, StartTime, EndTime, 
SPID, ApplicationName, LoginName  
FROM sys.fn_trace_gettable(@path, DEFAULT)
WHERE EventClass IN (58)
ORDER BY StartTime DESC