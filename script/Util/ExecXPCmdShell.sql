SET QUOTED_IDENTIFIER OFF
go
IF OBJECT_ID('ExecXPCmdShell') IS NOT NULL  
	DROP PROC ExecXPCmdShell
GO
CREATE PROC ExecXPCmdShell 	@Cmd nvarchar(4000), 
				@DBName sysname, 
				@ProcName sysname,
				@LogDesc nvarchar(4000) = NULL OUTPUT
AS BEGIN
	--err handling vars
	DECLARE @err int, @rcnt int			--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @log_desc nvarchar(4000)			-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------


	IF OBJECT_ID('tempdb..#CmdShellOut', 'U') IS NULL BEGIN 
		CREATE TABLE #CmdShellOut (
			id int IDENTITY,
			nstr nvarchar(4000)
		)
	END
--PRINT @Cmd
	IF (left(@Cmd, 1) <> '"' OR right(@Cmd, 1) <> '"') BEGIN
		IF (patindex('%2>&1', @Cmd) = 0) SET @Cmd = @Cmd + ' 2>&1'
		SELECT @Cmd = '"' + @Cmd + '"'
	END
--PRINT @Cmd
	SELECT @stmnt_lastexec = "INSERT INTO #CmdShellOut (nstr)....",
			@LogDesc = @Cmd, 
			@err = NULL
	INSERT INTO #CmdShellOut (nstr)
		EXEC @err = master.dbo.xp_cmdshell @Cmd
	SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
	SELECT @LogDesc = @LogDesc + CHAR(10) + isNull(nstr, '') FROM #CmdShellOut ORDER BY id
	--DELETE #CmdShellOut
	IF (@err <> 0) GOTO Err

	RETURN @err

Err:
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @DBName, 
					@AgentName = @ProcName,
					@Statement = @stmnt_lastexec, 
					@ErrCode = @err, 
					@RecordCount = @rcnt, 
					@LogDesc = @LogDesc,
					@EMNotify = NULL, 
					@UserId = NULL
	RETURN @err
END 
GO