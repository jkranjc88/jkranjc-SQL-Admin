USE Horizon

BEGIN
SET NOCOUNT ON;

DECLARE @TableName VARCHAR(50)
DECLARE @IndexName VARCHAR(50)
DECLARE @Fragmentation VARCHAR(10)
DECLARE @RecommendedAction VARCHAR(50)
DECLARE @InfoMessage VARCHAR(150)

DECLARE @GetRow CURSOR

SET @GetRow = CURSOR FOR
SELECT TableName, IndexName, Fragmentation, RecommendedAction FROM
(
SELECT
  dbtables.[name] AS 'TableName', 
  dbindexes.[name] AS 'IndexName',
  CAST(ROUND(indexstats.avg_fragmentation_in_percent, 0) AS varchar) + '%' AS 'Fragmentation',
  CASE 
   WHEN avg_fragmentation_in_percent < 30 THEN 'REORGANIZE'
   ELSE 'REBUILD WITH (SORT_IN_TEMPDB = ON)'
  END AS 'RecommendedAction'
 FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS indexstats
  INNER JOIN sys.tables dbtables on dbtables.[object_id] = indexstats.[object_id]
  INNER JOIN sys.schemas dbschemas on dbtables.[schema_id] = dbschemas.[schema_id]
  INNER JOIN sys.indexes AS dbindexes ON dbindexes.[object_id] = indexstats.[object_id] AND indexstats.index_id = dbindexes.index_id
 WHERE indexstats.database_id = DB_ID()
   AND indexstats.page_count > 500
   AND dbindexes.[name] IS NOT NULL
   AND indexstats.avg_fragmentation_in_percent >= 5
) AS IndexFragmentationTable

SET @InfoMessage = 'Began fixing indexes on ' + DB_NAME()
EXEC XP_LOGEVENT 52221, @InfoMessage

OPEN @GetRow
FETCH NEXT
FROM @GetRow INTO @TableName, @IndexName, @Fragmentation,@RecommendedAction
WHILE @@FETCH_STATUS = 0
BEGIN
 BEGIN TRAN IndexFix
  SET @InfoMessage = 'Running ' + @RecommendedAction + ' on index ' + @IndexName + ' (' + @Fragmentation + ' fragmentation) in database ' + DB_NAME()
  EXEC XP_LOGEVENT 52221, @InfoMessage
  EXEC('ALTER INDEX ' + @IndexName + ' ON ' + @TableName + ' '+@RecommendedAction+';')
 COMMIT TRAN IndexFix

 FETCH NEXT
 FROM @GetRow INTO @TableName, @IndexName, @Fragmentation, @RecommendedAction
END
CLOSE @GetRow
DEALLOCATE @GetRow

SET @InfoMessage = 'Finished fixing indexes on ' + DB_NAME()
EXEC XP_LOGEVENT 52221, @InfoMessage

END