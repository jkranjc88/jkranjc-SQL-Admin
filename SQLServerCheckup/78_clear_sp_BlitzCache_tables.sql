IF OBJECT_ID('tempdb.dbo.##BlitzCacheProcs', 'U') IS NOT NULL
    EXEC ('DROP TABLE ##BlitzCacheProcs;')

IF OBJECT_ID('tempdb.dbo.##BlitzCacheResults', 'U') IS NOT NULL
    EXEC ('DROP TABLE ##BlitzCacheResults;')
