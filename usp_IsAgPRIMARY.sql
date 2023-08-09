-- =============================================
-- Author:		Jure Kranjc
-- Create date: 31.12.9999
-- Description:	Check if Server is PRIMARY
-- =============================================
CREATE PROCEDURE [dbo].[IsAoAGPrimary]
	@serverName AS VARCHAR(50) 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--DECLARE @ServerName NVARCHAR(60) = @@SERVERNAME
	DECLARE @roleDesc NVARCHAR(60)

	SELECT @RoleDesc = a.role_desc
	FROM sys.dm_hadr_availability_replica_states AS a
	JOIN sys.availability_replicas AS b ON b.replica_id = a.replica_id
	WHERE b.replica_server_name = @serverName

	IF @roleDesc = 'PRIMARY'
	BEGIN
		SELECT 1;
	END
	ELSE
	BEGIN
		SELECT 0;
	END

END
GO


