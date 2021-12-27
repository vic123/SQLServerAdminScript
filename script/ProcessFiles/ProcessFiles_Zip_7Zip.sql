SET QUOTED_IDENTIFIER OFF
go
IF OBJECT_ID('ProcessFiles_Zip_7Zip') IS NOT NULL  
  DROP PROC ProcessFiles_Zip_7Zip
GO
CREATE PROC ProcessFiles_Zip_7Zip 	--   SET QUOTED_IDENTIFIER OFF
						@Dir nvarchar(4000), --with ending "\"
						@FileName nvarchar(4000),
						@TargetDir$ZipFilePrefix nvarchar (500),
						@Move bit = 0,
						@TempPath nvarchar(500) = NULL
/*
Zips (optionally moves) @FileName into @FileName + '.zip'

Test:
 

ProcessFiles_v2	@Dir = 'W:\RAC\SQLAdmin\ZipCopy\test\src\tryout',
--		@PreCommand nvarchar(4000) = NULL,
--		@FileDetailsCommand nvarchar(4000) = NULL,
--		@FileListCommand = 
	@FileCommand = 'EXEC @err = ProcessFiles_Zip_7Zip @Dir = ''{dir}'', @FileName = ''{file}'', @TargetDir$ZipFilePrefix = ''W:\RAC\SQLAdmin\ZipCopy\test\src\'', @Move = 0, @TempPath = ''w:\tmp''', 	
--	@PostCommand nvarchar(4000) = NULL,
--	@FileMaskList nvarchar(1000) = '%',		--(list, ":" delimited), only '%' symbols for zipping 
--	@ExceptFileMaskList nvarchar(1000),			-- ('_' will not work)
	@Recurs = 1,
--	@DaysOld int =  0,
	@EmailList = 'victor@michaeljoubert.com',
	@EmailSubjAction = 'Zip_7Zip-local test'
	

""%ProgramFiles%\7-Zip\7z.exe" 7z u -tzip "W:\RAC\SQLAdmin\ZipCopy\test\src\sp_tracecreate.sql.zip" "W:\RAC\SQLAdmin\ZipCopy\test\src\tryout\sp_tracecreate.sql" 2>&1"


""%ProgramFiles%\7-Zip\7z.exe" 7z u -tzip "W:\RAC\SQLAdmin\ZipCopy\test\src\sp_tracecreate.sql.zip" "W:\RAC\SQLAdmin\ZipCopy\test\src\tryout\sp_tracecreate.sql" 2>&1" 


7-Zip 4.42  Copyright (c) 1999-2006 Igor Pavlov  2006-05-14 Error: Incorrect command line



SELECT TOP 100 * FROM SQL_ERR_LOG ORDER BY ErrId DESC
No description. Check ErrCode (= 2), RecordCount (= 7) and SysMessage fields



*/
AS BEGIN

SET QUOTED_IDENTIFIER ON
	--err handling vars
	DECLARE @proc_name sysname, @db_name sysname    			--used for unified calling of ADM_WRITE_SQL_ERR_LOG
	SELECT @proc_name = name, @db_name = db_Name() 
		FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int			--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @log_desc nvarchar(4000)			-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------
	DECLARE @hr_obj int				-- var for OAGetErrorInfo
	DECLARE @hr int


	--log input params
	SET @log_desc = '@Dir nvarchar(4000) = ' + isNull('''' + @Dir + '''', 'NULL') + CHAR(10)
			+ '@FileName nvarchar(4000) = ' + isNull('''' + @FileName + '''', 'NULL') + CHAR(9) + CHAR(10) 
			+ '@TargetDir$ZipFilePrefix nvarchar(500) = ' + isNull('''' + @TargetDir$ZipFilePrefix + '''', 'NULL') + CHAR(10) 
			+ '@Move bit: ' + isNull(convert(varchar(100), @Move), 'NULL') + CHAR(10)
			+ '@TempPath nvarchar(500) = ' + isNull('''' + @TempPath + '''', 'NULL') + CHAR(10) 


	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name,
					@AgentName = @proc_name,
					@Statement = '/**** Input parameters ****/',
					@RecordCount = @rcnt,
					@LogDesc = 	@log_desc,
					@UserId = NULL,
					@IsLogOnly = 1
	SET @log_desc = ''
	
	DECLARE @SUCCESS_PROCESS_FLAG int, @ERROR_PROCESS_FLAG int
	SELECT 	@SUCCESS_PROCESS_FLAG 	= 0x01,
		@ERROR_PROCESS_FLAG 	= 0x04


	DECLARE @cmd nvarchar(4000)
	CREATE TABLE #ZipOut	(id int IDENTITY, 
				nstr nvarchar(4000)
		)

	SELECT @cmd = '"'
	--7zip created temp file in working folder (system32); at least when zip already existed (in zip update mode)
	IF @TempPath IS NOT NULL BEGIN 
		SET @cmd = @cmd + left(@TempPath, 2)
		SET @cmd = @cmd + ' && cd ' + substring(@TempPath, 3, len(@TempPath)) + ' && '
	END
	
	SELECT @cmd = @cmd + '"%ProgramFiles%\7-Zip\7z.exe" u -tzip "' + @TargetDir$ZipFilePrefix + @FileName + '.zip" "' + @Dir + @FileName + '" 2>&1"'
--SELECT @cmd 

	SELECT @stmnt_lastexec = "INSERT INTO #ZipOut (nstr)....",
		@log_desc = @cmd, 
		@err = NULL
	INSERT INTO #ZipOut (nstr)
		EXEC @err = master.dbo.xp_cmdshell @cmd
	SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
--PRINT @err
	IF (@err <> 0) BEGIN
		IF OBJECT_ID('tempdb..#FileDir', 'U') IS NOT NULL BEGIN 
			UPDATE det SET ProcessFlag = ProcessFlag | @ERROR_PROCESS_FLAG
			FROM #FileDetail det 
				JOIN #FilePath path ON det.FilePathId = path.id
				JOIN #FileDir dir ON path.FileDirId = dir.id
			WHERE Dir = @Dir AND FileName = @FileName
		END
		DELETE FROM #ZipOut WHERE nstr IS NULL
		SELECT @log_desc = @log_desc + CHAR(10) + nstr FROM #ZipOut ORDER BY id
		GOTO Err
	END ELSE BEGIN
		IF OBJECT_ID('tempdb..#FileDir', 'U') IS NOT NULL BEGIN 
			UPDATE det SET ProcessFlag = ProcessFlag | @SUCCESS_PROCESS_FLAG
			FROM #FileDetail det 
				JOIN #FilePath path ON det.FilePathId = path.id
				JOIN #FileDir dir ON path.FileDirId = dir.id
			WHERE Dir = @Dir AND FileName = @FileName
		END

		EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name,
						@AgentName = @proc_name,
						@Statement = @stmnt_lastexec,
						@RecordCount = @rcnt,
						@LogDesc = 	@log_desc,
						@UserId = NULL,
						@IsLogOnly = 1
		SET @log_desc = ''
	END

	IF (@Move <> 0) BEGIN
		EXEC @err = ProcessFiles_Delete_v2 @Dir = @Dir, @FileName = @FileName
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
	END
	RETURN 0

Err:
	IF @err = 0 SET @err = -1
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