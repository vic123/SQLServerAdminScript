SET QUOTED_IDENTIFIER OFF
go
IF OBJECT_ID('ExecXPDirTree') IS NOT NULL  
  DROP PROC ExecXPDirTree
GO

CREATE PROC ExecXPDirTree 	@Dir nvarchar(3000), 
				@Recurs bit = 0
AS BEGIN
	--err handling vars
	DECLARE @err int, @rcnt int			--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @log_desc nvarchar(4000)			-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------
	DECLARE @proc_name sysname, @db_name sysname    			--used for unified calling of ADM_WRITE_SQL_ERR_LOG
	SELECT @proc_name = name, @db_name = db_Name() 
		FROM sysobjects WHERE id = @@PROCID


	SET @log_desc = '@Dir nvarchar(3000) = ' + isNull('''' + @Dir + '''', 'NULL') + CHAR(10)
			+ '@Recurs bit: ' + isNull(convert(varchar(100), @Recurs), 'NULL') + CHAR(10)
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name,
					@AgentName = @proc_name,
					@Statement = '/**** Input parameters ****/',
					@RecordCount = @rcnt,
					@LogDesc = 	@log_desc,
					@UserId = NULL,
					@IsLogOnly = 1
	SET @log_desc = ''


/*
	CREATE TABLE #DirTree (
		id int IDENTITY PRIMARY KEY,
		subdirectory nvarchar(3000),
		filename nvarchar(500),
		depth	int,
		is_file	bit,	--do not rely on it !!! - it is not set for recursive operation
		processflag int
	)
*/

	DECLARE @cur_dir nvarchar(3000), @last_id int
	SELECT @cur_dir = @Dir

	WHILE (1 = 1) BEGIN

		IF right(@cur_dir, 1) <> '\' SELECT @cur_dir = @cur_dir + '\'

		SELECT @last_id = isNull(max(id), 0) FROM #DirTree
		SELECT 	@stmnt_lastexec = "INSERT INTO #DirTree (subdirectory, depth, is_file) ...",
			@log_desc = @cur_dir
			
		INSERT INTO #DirTree (subdirectory, depth, is_file)
				--master.dbo.xp_dirtree 'c:\', 1==do not recurse, 1==list files
				EXEC @err = master.dbo.xp_dirtree @cur_dir, 1, 1
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
		IF (@err <> 0) BEGIN
			EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
							@AgentName = @proc_name,
							@Statement = @stmnt_lastexec, 
							@ErrCode = @err, 
							@RecordCount = @rcnt, 
							@LogDesc = @log_desc,
							@EMNotify = NULL, 
							@UserId = NULL,
							@IsWarnOnly = 1
		END
		--convert data to our internal representation
		UPDATE #DirTree SET filename = subdirectory, subdirectory = @cur_dir 
			WHERE id > @last_id
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT 
		IF (@err <> 0) GOTO Err
		IF @Recurs = 0 BREAK
		UPDATE #DirTree SET processflag = 1 WHERE subdirectory + filename + '\' = @cur_dir
		SET @cur_dir = NULL
		SELECT TOP 1 @cur_dir = subdirectory + filename 
			FROM #DirTree WHERE processflag IS NULL AND is_file = 0
			AND EXISTS (SELECT * 
						FROM #FileMask 
						WHERE filename LIKE nstr)
				AND NOT EXISTS (SELECT * FROM #ExceptFileMask
						WHERE filename LIKE nstr
				)

		IF @cur_dir IS NULL BREAK
--SELECT @cur_dir, * FROM   #DirTree 
	END
	UPDATE #DirTree SET processflag = NULL
	
	RETURN 0

Err:
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
					@AgentName = @proc_name,
					@Statement = @stmnt_lastexec, 
					@ErrCode = @err, 
					@RecordCount = @rcnt, 
					@LogDesc = @log_desc,
					@EMNotify = NULL, 
					@UserId = NULL
	RETURN @err
END 
GO