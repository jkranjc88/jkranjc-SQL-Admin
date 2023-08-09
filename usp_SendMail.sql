/*-- ======================================================================================
-- Author:		Jure Kranjc
-- Create date: 31.12.9999
-- Description:	Procedura za pošiljanje mailov
-- Version: 1.00
-- ======================================================================================*/
CREATE PROCEDURE [dbo].[usp_SendMail]
	@subjectContent AS VARCHAR(MAX),
	@text AS VARCHAR(MAX),
	@table AS NVARCHAR(MAX) = '',
	@from AS VARCHAR(MAX),
	@to AS VARCHAR(MAX),
	@cc AS VARCHAR(MAX) = NULL
AS
BEGIN
	DECLARE @QueryString NVARCHAR(MAX)  = '';
	DECLARE @DateCreated AS VARCHAR(10) = CONVERT(VARCHAR(10),GETDATE(),104);
	DECLARE @DateCreated2 AS VARCHAR(10) = CONVERT(VARCHAR(10),GETDATE(),112);
	DECLARE @NewLineChar AS CHAR(2) = CHAR(13) + CHAR(10);
	DECLARE @subject AS VARCHAR(MAX) = @subjectContent
	DECLARE @style AS NVARCHAR(MAX) = N'<style type="text/css">
				#box-table
				{
					font-family: "CourieR New";
					font-size: 11px;
					text-align: left;
					padding: 5px;
					border-collapse: collapse;
				}
				#box-table th
				{
					font-size: 12px;
					font-weight: bold;
					border: 1px solid #000000;
					background: #ffffff;
				}
				#box-table td
				{
					border: 1px solid #000000;
					vertical-align: text-top;
				}
			</style>
			<font face="CourieR New" size="11px">'
	DECLARE @textAndTable AS NVARCHAR(MAX) = '<p style="font-size:12px">' + @text + '</p>' + @table;
	DECLARE @HtmlBody AS NVARCHAR(MAX) = @style + @textAndTable;

	EXEC msdb.dbo.sp_send_dbmail
		@profile_name = 'DatabaseMailProfil',
		@from_address= @from,
		@recipients = @to,
		@copy_recipients = @cc,
		@subject =  @subject,
		@body = @HtmlBody,
		@query_result_no_padding = 1,
		@query_result_separator = '	',
		@query_result_header = 1,
		@body_format = 'HTML';
END
GO


