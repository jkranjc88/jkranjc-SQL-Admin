-- =============================================
-- Author:		<Jure Kranjc>
-- Create date: <31.12.9999>
-- Description:	<Procedura za preverjanje konsistentnosti podatkovne baze>
-- =============================================
CREATE PROCEDURE [dbo].[usp_DBIntegrityCheck]
AS
BEGIN
	SET NOCOUNT ON;

	--DBCC CHECKDB(N'Horizon', NOINDEX) WITH NO_INFOMSGS;

	IF OBJECT_ID('tempdb..#TMP') IS NOT NULL
	DROP TABLE #TMP;

	CREATE TABLE #TMP (LogDate DATETIME, ProcessInfo VARCHAR(20), Text VARCHAR(500));

	INSERT INTO #TMP
	EXEC xp_readErrorLog 0, 1, N'CHECKDB';

	DECLARE @timeStamp AS VARCHAR(14) = CONVERT(VARCHAR,GETDATE(),112) + 'T' + CONVERT(VARCHAR,DATEPART(HH,GETDATE())) + CONVERT(VARCHAR,DATEPART(MI,GETDATE())) + CONVERT(VARCHAR,DATEPART(SS,GETDATE()));
	DECLARE @subject AS VARCHAR(50) = '#DBIntegrityCheck_' + @timeStamp + ': DBCC CHECKDB'
	DECLARE @table AS NVARCHAR(2500);
	DECLARE @command AS VARCHAR(50) = 'EXEC xp_readErrorLog 0, 1, N''CHECKDB'';';

	SET @table = N'<table id="box-table">
							<tr>
							<th>LOGDATE</th>
							<th>PROCESSINFO</th>		
							<th>TEXT</th>
							</tr>' +
							CAST( ( SELECT td = LogDate,'',
											td = ProcessInfo,'',
											--td = Text,''
											td = SUBSTRING(Text, CHARINDEX('(',Text), CHARINDEX(')',Text)+1 - CHARINDEX('(',Text)) + ': ' + SUBSTRING(Text,CHARINDEX('found',Text,1),(CHARINDEX('. Elapsed',Text,1) - CHARINDEX('found',Text,1))),''
									FROM	#TMP
									FOR XML PATH('tr'), TYPE
								) AS NVARCHAR(MAX) 
								) + 
						N'</table>';

	EXEC [dbo].[usp_SendMail] @subject, @command, @table, 'sendmail@from.si', 'someone@sample.si';
END
GO


