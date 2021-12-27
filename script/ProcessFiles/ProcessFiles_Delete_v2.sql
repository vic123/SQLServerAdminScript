SET QUOTED_IDENTIFIER OFF
GO
IF OBJECT_ID('ProcessFiles_Delete_v2') IS NOT NULL  
  DROP PROCEDURE ProcessFiles_Delete_v2
GO

CREATE PROCEDURE ProcessFiles_Delete_v2 	@Dir nvarchar(260), --with ending "\"
					@FileName nvarchar(500) AS 
/***************************************************************************************************
Use as parameter of 
ProcessFiles @FileCommand = 'EXEC @err = ProcessFiles_Delete_v2 ''{dir}'', ''{file}'''

test:
EXEC ProcessFiles_Delete_v2 @Dir = 'D:\SQLBackup\tmp\', @FileName = 'DFSC_MakeScript.bat'

Modifications:
070324, vic123 - Adopted UPDATE #FileDetail to 3 tables as they are in ProcessFiles_v2.sql
***************************************************************************************************/
BEGIN
	DECLARE @SUCCESS_PROCESS_FLAG int, @SKIPPED_PROCESS_FLAG int, @DELETED_PROCESS_FLAG int, 
		@ERROR_PROCESS_FLAG int, @UNLOGGED_ERROR_PROCESS_FLAG int
	SELECT 	@SUCCESS_PROCESS_FLAG 	= 0x01,
		@DELETED_PROCESS_FLAG 	= 0x02,
		@ERROR_PROCESS_FLAG 	= 0x04,
		@UNLOGGED_ERROR_PROCESS_FLAG	= 0x08,
		@SKIPPED_PROCESS_FLAG	= 0x10


	DECLARE @proc_name sysname, @db_name sysname	--used for unified calling of ADM_WRITE_SQL_ERR_LOG
	SELECT @proc_name = name, @db_name = db_Name() FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int			--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @log_desc nvarchar(255)			-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------
	DECLARE @hr_obj int				-- var for OAGetErrorInfo
	DECLARE @hr	int

	DECLARE @fso int
--	DECLARE @folder int
--	DECLARE @file int


	DECLARE @file_path nvarchar(260)
	SET @file_path = @Dir + @FileName

	SELECT 	@stmnt_lastexec = "EXEC @hr=sp_OACreate 'Scripting.FileSystemObject', @hr_obj OUT"
	EXEC @hr=sp_OACreate 'Scripting.FileSystemObject', @hr_obj OUT
	IF (@hr <> 0) GOTO OAErr
	SELECT 	@fso = @hr_obj
	SELECT 	@hr_obj = @fso,
		@stmnt_lastexec = "EXEC @hr = sp_OAMethod @fso,'DeleteFile', NULL, @file_path",
		@log_desc = @file_path
--SELECT @file_path
--SELECT @hr = 1
--return 1
	EXEC @hr = sp_OAMethod @fso,'DeleteFile', NULL, @file_path
	IF (@hr = 0) BEGIN
		IF OBJECT_ID('tempdb..#FileDir', 'U') IS NOT NULL BEGIN 
			UPDATE det SET ProcessFlag = ProcessFlag | @DELETED_PROCESS_FLAG | @SUCCESS_PROCESS_FLAG
	--				WHERE CURRENT OF ProcessFiles_filedetail_cur
			FROM #FileDetail det 
				JOIN #FilePath path ON det.FilePathId = path.id
				JOIN #FileDir dir ON path.FileDirId = dir.id
			WHERE Dir = @Dir AND FileName = @FileName
		END
	END ELSE BEGIN
		SET @log_desc = isNull(@log_desc + '; ', '') + dbo.OAGetErrorInfo (@hr_obj, @hr)
		EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name,
						@AgentName = @proc_name,
						@Statement = @stmnt_lastexec,
						@RecordCount = @rcnt,
						@LogDesc = 	@log_desc,
						@UserId = NULL,
						@IsWarnOnly = 1
		SET @log_desc = ''
		IF OBJECT_ID('tempdb..#FileDir', 'U') IS NOT NULL BEGIN 
			UPDATE det SET ProcessFlag = ProcessFlag | @ERROR_PROCESS_FLAG
	--			WHERE CURRENT OF ProcessFiles_filedetail_cur
	--					WHERE Dir = @Dir AND FileName = @FileName
				FROM #FileDetail det 
					JOIN #FilePath path ON det.FilePathId = path.id
					JOIN #FileDir dir ON path.FileDirId = dir.id
				WHERE Dir = @Dir AND FileName = @FileName
		END
	END

	EXEC sp_OADestroy @fso

	RETURN 0

OAErr:
	SET @log_desc = isNull(@log_desc, '') + dbo.OAGetErrorInfo (@hr_obj, @hr)
	SELECT @log_desc
	SET @err = @hr
Err:
	IF (@fso IS NOT NULL) EXEC sp_OADestroy @fso
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







