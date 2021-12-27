SET QUOTED_IDENTIFIER OFF
GO
DROP PROCEDURE aspr_GetLogicalLogNameAndDrive 
GO
CREATE PROCEDURE aspr_GetLogicalLogNameAndDrive @LogicalLogName sysname OUT, 
												@LogDrive char(1) OUT
AS BEGIN

	DECLARE @proc_name sysname					--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	SELECT @proc_name = name FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int					--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @logmsg nvarchar(255)				-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------

	SELECT 	@stmnt_lastexec = "CREATE TABLE #aspr_GetLogicalLogName_helpfile	(..."
	CREATE TABLE #aspr_GetLogicalLogName_helpfile	(
				name 		sysname,
				fileid 		smallint,
				filename	nchar(260),
				filegroup	sysname NULL,
				size		nvarchar(18),
				maxsize		nvarchar(18),
				growth		nvarchar(18),
				usage		varchar(9)
		)
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	SELECT 	@stmnt_lastexec = "INSERT #aspr_GetLogicalLogName_helpfile EXEC sp_helpfile"
	INSERT #aspr_GetLogicalLogName_helpfile EXEC sp_helpfile
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	SELECT 	--@LogicalLogName = FILE_NAME(fileid),
			@LogicalLogName = rTrim(name),
			@LogDrive = left(filename,1)
	FROM #aspr_GetLogicalLogName_helpfile WHERE usage = 'log only'

	RETURN 0
Err:
--	DECLARE @em_notify nvarchar(1500)
--	SET @em_notify = isNull(@EMTo + ';', '') + isNull(@EMCCList, '')
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'DMDBA', 
								@AgentName = @proc_name,
								@Statement = @stmnt_lastexec, 
								@ErrCode = @err, 
								@RecordCount = @rcnt, 
								@LogDesc = @logmsg,
								@EMNotify = NULL, --@em_notify,
								@UserId = NULL
	RETURN @err
END
GO
SET QUOTED_IDENTIFIER ON
GO


/*
DECLARE @LogicalLogName sysname, @LogDrive char(1), @err int
exec @err = sp_executesql N'SELECT @LogicalLogName = rTrim(name), 	@LogDrive = left(filename,1) FROM DFSC_Test.dbo.sysfiles WHERE (status & 0x40) <> 0',
				N'@LogicalLogName sysname OUT, @LogDrive char(1) OUT',
				@LogicalLogName OUT, @LogDrive OUT
SELECT @LogicalLogName, @LogDrive, @err
*/
