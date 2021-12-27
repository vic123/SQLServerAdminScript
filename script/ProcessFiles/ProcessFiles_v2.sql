-- EXEC aspr_LS_DelOldFiles_ExtExceptions  'D:\SW_ARCH', 7
SET QUOTED_IDENTIFIER OFF
go
IF OBJECT_ID('ProcessFiles_v2') IS NOT NULL  
  DROP PROCEDURE  ProcessFiles_v2
GO
CREATE  PROCEDURE ProcessFiles_v2	--   SET QUOTED_IDENTIFIER OFF
	@Dir nvarchar(4000),
	@PreCommand nvarchar(4000) = NULL,
	@FileDetailsCommand nvarchar(4000) = NULL,
	@FileListCommand nvarchar(4000) = NULL,
	@FileCommand nvarchar(4000) = NULL,
	@PostCommand nvarchar(4000) = NULL,
	@FileMaskList nvarchar(1000) = '%',		--(list, ":" delimited), only '%' symbols for zipping 
	@ExceptFileMaskList nvarchar(1000) = NULL,			-- ('_' will not work)
	@Recurs bit = 0,
	@DaysOld int =  0,	--files that are full @DaysOld and older are processed. 
				--Hours and minutes of file date are not taken under account.
	@EmailList varchar(1000) = NULL,
	@EmailSubjAction nvarchar(30) = NULL

/**********************************************************************************************
Author			: Victor Blokhin(vic123.com)
Date			: Aug 2006
Purpose			: Perform custom operations over files
Tables Referred :
Sprocs Referred	:
**********************************************************************************************/
/*MODIFICATIONS HISTORY IN CHRONOLOGICAL ORDER, WITH THE LATEST CHANGE BEING AT THE TOP.*/
/********************************************************************************************
MODIFIED BY      : 	
MODIFICATIONS    :	
DATE             :
LABEL		 :  

**********************************************************************************************/

/***********************************************************************************************
DESCRIPTION
**********************************************************************************************/
/***********************************************************************************************
test:

ProcessFiles	@Dir = 'D:\SQLBackup\tmp\',
--		@PreCommand nvarchar(4000) = NULL,
--		@FileDetailsCommand nvarchar(4000) = NULL,
--		@FileListCommand nvarchar(4000) = NULL,
--	@FileCommand nvarchar(4000) = NULL,
--	@FileMaskList nvarchar(1000) = '%',		--(list, ":" delimited), only '%' symbols for zipping 
--	@ExceptFileMaskList nvarchar(1000),			-- ('_' will not work)
	@Recurs = 1,
--	@DaysOld int =  0,
	@EmailList = 'victor@infoplanet-usa.com',
	@EmailSubjAction = 'PureTest'

ProcessFiles	@Dir = 'D:\SQLBackup\tmp\',
--		@PreCommand nvarchar(4000) = NULL,
--		@FileDetailsCommand nvarchar(4000) = NULL,
		@FileListCommand = 'EXEC @err = ProcessFileList_ZipDaily @SourceDir = ''{dir}'', @TargetDir$ZipFilePrefix = ''D:\SQLArchive\SQLBackup'', @Recurs = {recurs}',
--	@FileCommand nvarchar(4000) = NULL,
--	@FileMaskList nvarchar(1000) = '%',		--(list, ":" delimited), only '%' symbols for zipping 
--	@ExceptFileMaskList nvarchar(1000),			-- ('_' will not work)
	@Recurs = 1,
--	@DaysOld int =  0,
	@EmailList = 'victor@infoplanet-usa.com',
	@EmailSubjAction = 'ZipDaily'


ProcessFiles	@Dir = 'D:\SQLBackup\tmp\',
--		@PreCommand nvarchar(4000) = NULL,
--		@FileDetailsCommand nvarchar(4000) = NULL,
--		@FileListCommand = 'EXEC @err = ProcessFiles_ZipDaily @SourceDir = ''{dir}'', @TargetDir$ZipFilePrefix = ''D:\SQLArchive\SQLBackup''',
	@FileCommand = 'EXEC @err = ProcessFiles_Delete ''{dir}'', ''{file}''',
--	@FileMaskList nvarchar(1000) = '%',		--(list, ":" delimited), only '%' symbols for zipping 
--	@ExceptFileMaskList nvarchar(1000),			-- ('_' will not work)
	@Recurs = 0,
	@DaysOld =  16,
	@EmailList = 'victor@infoplanet-usa.com',
	@EmailSubjAction = 'DeleteOld'


ProcessFiles	@Dir = 'D:\SQLBackup\bkpouter\',
--ProcessFiles	@Dir = 'D:\SQLBackup\bkpouter\bkpinner\',
--		@PreCommand nvarchar(4000) = NULL,
--		@FileDetailsCommand nvarchar(4000) = NULL,
		@FileListCommand = 'EXEC @err = ProcessFileList_ZipDaily @SourceDir = ''{dir}'', @TargetDir$ZipFilePrefix = ''D:\SQLArchive\SQLBackup'', @Recurs = {recurs}',
--	@FileCommand nvarchar(4000) = NULL,
--	@FileMaskList nvarchar(1000) = '%',		--(list, ":" delimited), only '%' symbols for zipping 
--	@ExceptFileMaskList nvarchar(1000),			-- ('_' will not work)
	@Recurs = 1,
--	@DaysOld int =  0,
	@EmailList = 'victor@infoplanet-usa.com',
	@EmailSubjAction = 'ZipDaily'


ProcessFiles	@Dir = 'X:\SQLBackup\bkpouter\',
--ProcessFiles	@Dir = 'D:\SQLBackup\bkpouter\bkpinner\',
--		@PreCommand nvarchar(4000) = NULL,
--		@FileDetailsCommand nvarchar(4000) = NULL,
		@FileListCommand = 'EXEC @err = ProcessFileList_ZipDaily @SourceDir = ''{dir}'', @TargetDir$ZipFilePrefix = ''D:\SQLArchive\SQLBackup'', @Recurs = {recurs}',
--	@FileCommand nvarchar(4000) = NULL,
--	@FileMaskList nvarchar(1000) = '%',		--(list, ":" delimited), only '%' symbols for zipping 
--	@ExceptFileMaskList nvarchar(1000),			-- ('_' will not work)
	@Recurs = 1,
--	@DaysOld int =  0,
	@EmailList = 'victor@infoplanet-usa.com',
	@EmailSubjAction = 'ZipDaily'



EXEC master..xp_getfiledetails 'C:\W95UNDO.INI'
EXEC master..xp_getfiledetails 'C:\word'
EXEC master..xp_getfiledetails 'W:\RAC\SQLAdmin\ZipCopy\bin\test.txt'
1==ro
2==h
4==system (+S)
16==directory

3==ro,h
128 - nothing (-ro,-h,-a)
32 - archive
35 - all (+ro,+h,+a)


ToDO:
1. Separate Filenames from path 
2. Directories included in processing!!!!

3.!!! subdirectory moved to filename
4. !!! ZipDaily
@mindate = min(dbo.IntDT2DT(LastWrittenDate, LastWrittenTime))
		FROM #FileDetail
++ WHERE Attribute & DIRA = 0



SELECT TOP 100 * FROM SQL_ERR_LOG order by Errid Desc
SELECT TOP 100 * FROM SQL_ERR_LOG 
	WHERE Agentname = 'CDOSysSendMail'
	order by Errid Desc


Server: Msg 50000, Level 16, State 1, Procedure ADM_WRITE_SQL_ERR_LOG, Line 384
@ErrCode:	1; 
@Statement:	INSERT INTO #FileDetail	(AlternateName, Size, ...; 
@LogDesc:	


PseudoCode:
1. IF @Recurs = 0
1.1 use xp_dirtree
1.2 ELSE 'dir /S /o /b ' + @Dir + replace(nstr, '%', '*') and parse output into #DirTree
2. For Each #DirTree 
	master..xp_getfiledetails INTO #FileDetail, 
	INSERT INTO #FileDir, update #FileDetail, call  @FileDetailsCommand

**********************************************************************************************/



AS BEGIN
SET NOCOUNT ON
	DECLARE @SUCCESS_PROCESS_FLAG int, @SKIPPED_PROCESS_FLAG int, @DELETED_PROCESS_FLAG int, 
		@ERROR_PROCESS_FLAG int, @UNLOGGED_ERROR_PROCESS_FLAG int
	SELECT 	@SUCCESS_PROCESS_FLAG 	= 0x01,
		@DELETED_PROCESS_FLAG 	= 0x02,
		@ERROR_PROCESS_FLAG 	= 0x04,
		@UNLOGGED_ERROR_PROCESS_FLAG	= 0x08,
		@SKIPPED_PROCESS_FLAG	= 0x10
	
	DECLARE @proc_name sysname, @db_name sysname    			--used for unified calling of ADM_WRITE_SQL_ERR_LOG
	SELECT @proc_name = name, @db_name = db_Name() 
		FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int			--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @log_desc nvarchar(4000)			-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------
	DECLARE @hr_obj int				-- var for OAGetErrorInfo
	DECLARE @hr int

	DECLARE @cmd nvarchar(4000)
		
	SET @log_desc = '@Dir nvarchar(4000) = ' + isNull('''' + @Dir + '''', 'NULL') + CHAR(10)
			+ '@PreCommand nvarchar(4000) = ' + isNull('''' + @PreCommand + '''', 'NULL') + CHAR(9) + CHAR(10) 
			+ '@FileDetailsCommand nvarchar(4000) = ' + isNull('''' + @FileDetailsCommand + '''', 'NULL') + CHAR(9) + CHAR(10) 
			+ '@FileListCommand nvarchar(4000)  = ' + isNull('''' + @FileListCommand + '''', 'NULL') + CHAR(10)
			+ '@FileCommand nvarchar(4000)  = ' + isNull('''' + @FileCommand + '''', 'NULL') + CHAR(10)
			+ '@FileMaskList nvarchar(1000)  = ' + isNull('''' + @FileMaskList + '''', 'NULL') + CHAR(10)
			+ '@ExceptFileMaskList nvarchar(1000)  = ' + isNull('''' + @ExceptFileMaskList + '''', 'NULL') + CHAR(10)
			+ '@Recurs int: ' + isNull(convert(varchar(100), @Recurs), 'NULL') + CHAR(10)
			+ '@DaysOld int: ' + isNull(convert(varchar(100), @DaysOld), 'NULL') + CHAR(10)
			+ '@EmailList varchar(1000)  = ' + isNull('''' + @EmailList + '''', 'NULL') 
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name,
					@AgentName = @proc_name,
					@Statement = '/**** Input parameters ****/',
					@RecordCount = @rcnt,
					@LogDesc = 	@log_desc,
					@UserId = NULL,
					@IsLogOnly = 1
	SET @log_desc = ''

/*
	SELECT 	@hr_obj = @fso,
			@stmnt_lastexec = "EXEC @hr = sp_OAMethod @fso,'GetFolder', @folder OUT,
@Dir"
    EXEC @hr = sp_OAMethod @fso,'GetFolder', @folder OUT, @Dir
    IF (@hr <> 0) GOTO OAErr
*/

	--convert input lists into tables
	SELECT @stmnt_lastexec = "SELECT * INTO #..... FROM StringListToTable (..... "
	SELECT * INTO #FileMask FROM StringListToTable (@FileMaskList, ':')
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF @err <> 0 GOTO Err
	SELECT * INTO #ExceptFileMask FROM StringListToTable (@ExceptFileMaskList, ':')
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF @err <> 0 GOTO Err

	CREATE TABLE #DirTree (
		id int IDENTITY PRIMARY KEY,
		subdirectory nvarchar(3000),
		filename nvarchar(500),
		depth	int,
		is_file	bit,	--do not rely on it !!! - it is not set for recursive operation
		processflag int
	)
	CREATE TABLE #FileDir (
		id int IDENTITY PRIMARY KEY,
		dir nvarchar(3000)
	)
--	CREATE UNIQUE INDEX #FileDir_dir ON #FileDir (dir ASC)

	CREATE TABLE #FilePath (
		id int IDENTITY PRIMARY KEY,
		FileDirId int,
		FileName nvarchar(3000)
	)
--	CREATE UNIQUE INDEX #FilePath_FileDirIdFileName ON #FilePath (FileDirId ASC, FileName ASC)

	CREATE TABLE #FileDetail
	(
		id int IDENTITY PRIMARY KEY,
--!!!		Dir nvarchar(260),
		FilePathId int,
--!!!		FileName nvarchar(4000),
		AlternateName varchar(32),
		Size bigint,
		CreationDate int,
		CreationTime int,
		LastWrittenDate int,
		LastWrittenTime int,
		LastAccessedDate int,
		LastAccessedTime int,
		Attributes int,
		ProcessFlag int		
	)

	IF (right(@Dir, 1) <> '\') SET @Dir = @Dir + '\'


	IF @PreCommand IS NOT NULL BEGIN
		SELECT @cmd = replace(@PreCommand, '{dir}', @Dir)
		SELECT @log_desc = @cmd 
		SELECT 	@stmnt_lastexec = "EXEC sp_executesql @cmd, N'@err int OUTPUT', @err OUTPUT"
		EXEC sp_executesql @cmd, N'@err int OUTPUT', @err OUTPUT 
		IF (@err <> 0) GOTO Err
	END 	--IF @PreCommand IS NOT NULL BEGIN


	EXEC ExecXPDirTree @Dir, @Recurs

/*
	IF @Recurs = 0 BEGIN -- use master.dbo.xp_dirtree
		SELECT 	@stmnt_lastexec = "INSERT INTO #DirTree (subdirectory, depth, is_file) ..."
		INSERT INTO #DirTree (subdirectory, depth, is_file)
				--master.dbo.xp_dirtree 'c:\', 1==do not recurse, 1==list files
				EXEC master.dbo.xp_dirtree @Dir, 1, 1
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
		--convert data to our internal representation
		UPDATE #DirTree SET filename = subdirectory, subdirectory = @Dir --with no recurce it is so
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT 
		IF (@err <> 0) GOTO Err
	END ELSE BEGIN -- @Recurs = 1, use dir /S
		DECLARE @DIR_EXE nvarchar(4000)
		SELECT @stmnt_lastexec = "SELECT @DIR_EXE = @DIR_EXE = @DIR_EXE + ' ' + @Dir + replace(nstr, '%', '*') ..."
--(060917)!!		SELECT @DIR_EXE = 'dir /o /b /A-D ' + @Dir + replace(nstr, '%', '*') 
		SELECT @DIR_EXE = 'dir /o /b ' + @Dir --+ replace(nstr, '%', '*') FROM #FileMask
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF @err <> 0 GOTO Err
		IF @Recurs = 1 SELECT @DIR_EXE = @DIR_EXE + ' /S'

		----->>>DIR EXEC HERE>>>>>
--SELECT @DIR_EXE
		SELECT @stmnt_lastexec = "EXEC @err = master.dbo.xp_cmdshell @DIR_EXE",
			@log_desc = @DIR_EXE
		INSERT INTO #DirTree (subdirectory)
			EXEC @err = master.dbo.xp_cmdshell @DIR_EXE
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
--SELECT * FROM #DirTree	
		DELETE #DirTree WHERE subdirectory IS NULL
		IF @err <> 0 BEGIN
			SELECT @log_desc = @log_desc + CHAR(10) + isNull(subdirectory, '') FROM #DirTree ORDER BY id
			GOTO Err
		END



		DECLARE DirTree_cur CURSOR FOR SELECT id, subdirectory FROM #DirTree ORDER BY id
		DECLARE @id int, @subdir nvarchar(4000), @do_fetch bit
		SET @do_fetch = 1
		OPEN DirTree_cur 
		WHILE (1=1) BEGIN  --parse dir output
			IF @do_fetch = 1 FETCH NEXT FROM DirTree_cur INTO @id, @subdir
			IF @@FETCH_STATUS <> 0 BREAK
			SET @do_fetch = 1
			DECLARE @id1 int, @subdir1 nvarchar(4000)
			SELECT @subdir1 = @subdir
			WHILE len(@subdir1) = 255 BEGIN
				--when file path continues on next row(s) - fetch next and see if it is the case
				SET @do_fetch = 0
				FETCH NEXT FROM DirTree_cur INTO @id1, @subdir1
				IF @@FETCH_STATUS <> 0 BREAK
				IF patindex(@Dir, @subdir1) <> 1 BREAK
				ELSE SET @subdir = @subdir + @subdir1
			END
				--tryout:
				--			DECLARE @ci_start int, @subdir nvarchar(4000)
				--			SET @ci_start = 1
				--			SET @subdir = 'W:\Backup\test\_Btr2\corresp\041006_BTR_{Mirror}\_webdoc\sp_trace\SWYNK_COM SQL Archive [mssql] RE Audit Trail_files'
				--			SET @subdir = 'SWYNK_COM SQL Archive [mssql] RE Audit Trail_files'
				--			WHILE (CHARINDEX ('\', @subdir, @ci_start) <> 0) SET @ci_start = CHARINDEX ('\', @subdir, @ci_start) + 1
				--			SELECT left(@subdir, @ci_start-1), right(@subdir, len(@subdir) - @ci_start)
			DECLARE @ci_start int
			SELECT @ci_start = 1
			WHILE (CHARINDEX ('\', @subdir, @ci_start) <> 0) BEGIN
				SET @ci_start = CHARINDEX ('\', @subdir, @ci_start) + 1
			END
			UPDATE #DirTree SET 	subdirectory = left(@subdir, @ci_start-1), 
						filename = right(@subdir, len(@subdir) - @ci_start + 1)
				WHERE id = @id
				--tryout 
				--	SELECT * FROM sysobjects WHERE id BETWEEN 1 AND NULL
				--	SELECT * FROM sysobjects WHERE id BETWEEN 2 AND 2
			UPDATE #DirTree SET subdirectory = NULL WHERE id BETWEEN @id+1 AND @id1-1
			SELECT @subdir = @subdir1, @id = @id1
		END  --DirTree_cur
		CLOSE DirTree_cur
		DEALLOCATE DirTree_cur
		DELETE #DirTree WHERE subdirectory IS NULL
--(060917)!!		UPDATE #DirTree SET is_file = 1	--!!!
--		IF @Recurs = 1 UPDATE #DirTree SET subdirectory = subString(subdirectory, len(@Dir)+1, len(subdirectory))
	END ---- @Recurs = 1
*/

--SELECT * FROM #DirTree

	
--SELECT subdirectory, filename FROM #DirTree 
--SELECT subdirectory, filename FROM #DirTree WHERE 
--EXISTS (SELECT * FROM #FileMask WHERE filename LIKE nstr)
--AND NOT EXISTS (SELECT * FROM #ExceptFileMask WHERE filename LIKE nstr)


	DECLARE ProcessFileDetails_cur CURSOR LOCAL DYNAMIC TYPE_WARNING
		FOR SELECT subdirectory, filename
			FROM #DirTree 
--!!!			WHERE is_file = 1
			WHERE EXISTS (SELECT * 
						FROM #FileMask 
						WHERE filename LIKE nstr)
				AND NOT EXISTS (SELECT * FROM #ExceptFileMask
						WHERE filename LIKE nstr
				)
			ORDER BY subdirectory, filename
	DECLARE @id int, @file_name nvarchar(4000), @file_path nvarchar(4000), @file_dir nvarchar(4000)
	
	OPEN ProcessFileDetails_cur
	WHILE (1=1) BEGIN
		FETCH NEXT FROM ProcessFileDetails_cur INTO @file_dir, @file_name
		IF (@@FETCH_STATUS <> 0) BREAK
		SET @file_path = @file_dir + @file_name
--SELECT @file_path
		DECLARE @filedetail_id int, @filedir_id int, @filepath_id int
		SELECT 	@stmnt_lastexec = "INSERT INTO #FileDetail	(AlternateName, Size, ...",
			@log_desc = @file_path
		INSERT INTO #FileDetail	(AlternateName, Size, 
						CreationDate, CreationTime,
						LastWrittenDate, LastWrittenTime,
						LastAccessedDate, LastAccessedTime,
						Attributes
					)
			EXEC @err = xp_getfiledetails @file_path
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
		IF (@err <> 0 OR @rcnt <> 1) GOTO ErrCloseCurFileDetails
		SET @filedetail_id = SCOPE_IDENTITY()

			/*tryout:
				declare @i int
				SET @i = 1
				WHILE (@i < 10) BEGIN
					declare @j int
					SELECT @j 
					SET @j = @i
					SELECT @j 
					SET @i = @i + 1
				END
			*/

			/*tryout:
				declare @i int
				SET @i = 1
				SELECT @i 
				SELECT @i = id FROM sysobjects where id = 09348534985
				SELECT @i 
			*/
		SET @filedir_id = NULL
		SELECT @filedir_id = id FROM #FileDir WHERE dir = @file_dir
		IF @filedir_id IS NULL BEGIN 
			SELECT 	@stmnt_lastexec = "INSERT INTO #FileDir (dir) VALUES (@file_dir)...."
			INSERT INTO #FileDir (dir) SELECT @file_dir
			IF (@err <> 0 OR @rcnt <> 1) GOTO ErrCloseCurFileDetails
			SET  @filedir_id = SCOPE_IDENTITY()
		END
		
		SELECT 	@stmnt_lastexec = "INSERT INTO #FilePath (filedirid, filename) (@filedir_id, @file_name)"
		INSERT INTO #FilePath (filedirid, filename) VALUES (@filedir_id, @file_name)
		IF (@err <> 0 OR @rcnt <> 1) GOTO ErrCloseCurFileDetails
		SET  @filepath_id = SCOPE_IDENTITY()

		SELECT 	@stmnt_lastexec = "UPDATE #FileDetail SET Dir = @Dir, FileName = @file_name ..."
		UPDATE #FileDetail SET filepathid = @filepath_id
			WHERE id = @filedetail_id
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0 OR @rcnt <> 1) GOTO ErrCloseCurFileDetails

		IF @FileDetailsCommand IS NOT NULL BEGIN
			SELECT @cmd = replace(@FileDetailsCommand, '{dir}', replace(@file_dir, '''', ''''''))
			SELECT @cmd = replace(@cmd, '{file}', replace(@file_name, '''', ''''''))
			SELECT @log_desc = @cmd 
--PRINT @cmd
			SELECT 	@stmnt_lastexec = "EXEC @err = sp_executesql @cmd, N'@err int OUTPUT', @err OUTPUT"
			EXEC sp_executesql @cmd, N'@err int OUTPUT', @err OUTPUT 
--PRINT 11211
--PRINT @err
			IF (@err <> 0) GOTO ErrCloseCurFileDetails
		END 	--IF @FileDetailsCommand IS NOT NULL BEGIN
	END	--OPEN ProcessFileDetails_cur
	CLOSE ProcessFileDetails_cur
	DEALLOCATE ProcessFileDetails_cur

--PRINT 11221

	SELECT 	@stmnt_lastexec = "IF EXISTS (SELECT * FROM #FileDetail det LEFT OUTER JOIN #FilePath path ON = det.FilePathId = path.id ..."
	IF EXISTS (SELECT * FROM #FileDetail det LEFT OUTER JOIN #FilePath path ON det.FilePathId = path.id
				LEFT OUTER JOIN #FileDir dir ON path.FileDirId = dir.id
			WHERE dir.id IS NULL) GOTO Err
--PRINT 11231

	IF @FileListCommand IS NOT NULL BEGIN
		SELECT @cmd = replace(@FileListCommand, '{dir}', @Dir)
		SELECT @cmd = replace(@cmd, '{recurs}', convert(varchar, @Recurs))
		SELECT @log_desc = @cmd 
		SELECT 	@stmnt_lastexec = "EXEC sp_executesql @cmd, N'@err int OUTPUT', @err OUTPUT"
		EXEC sp_executesql @cmd, N'@err int OUTPUT', @err OUTPUT 
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
	END	--IF @FileListCommand IS NOT NULL BEGIN

	IF @FileCommand IS NOT NULL BEGIN
		DECLARE ProcessFiles_Files_cur CURSOR LOCAL DYNAMIC TYPE_WARNING
			FOR SELECT det.id, dir, FileName 
				FROM #FileDetail det JOIN #FilePath path ON det.FilePathId = path.id
					JOIN #FileDir dir ON path.FileDirId = dir.id
				WHERE 	--!!!is_file = 1
					convert (datetime, cast(LastWrittenDate as varchar(20)), 112)
						< dateAdd(dd, @DaysOld * -1, getDate())
		OPEN ProcessFiles_Files_cur
		WHILE (1=1) BEGIN
			FETCH NEXT FROM ProcessFiles_Files_cur INTO @id, @file_dir, @file_name	--<<<<???Warning: Null value is eliminated by an aggregate or other SET operation.
			IF (@@FETCH_STATUS <> 0) BREAK
			SELECT @cmd = replace(@FileCommand, '{dir}', @file_dir)
			SELECT @cmd = replace(@cmd, '{file}', @file_name)
			UPDATE #FileDetail SET ProcessFlag = 0 --ProcessFlag | @UNLOGGED_ERROR_PROCESS_FLAG
				WHERE CURRENT OF ProcessFiles_Files_cur
			SELECT 	@stmnt_lastexec = "EXEC sp_executesql @cmd, N'@err int OUTPUT', @err OUTPUT",
				@err = NULL,
				@log_desc = @cmd
			EXEC sp_executesql @cmd, N'@err int OUTPUT', @err OUTPUT 
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) BEGIN 
				IF EXISTS (SELECT * FROM #FileDetail det JOIN #FilePath path ON det.FilePathId = path.id
							JOIN #FileDir dir ON path.FileDirId = dir.id
						WHERE ProcessFlag = 0 
							AND Dir = @file_dir
							AND FileName = @file_name) BEGIN
					UPDATE #FileDetail SET ProcessFlag = ProcessFlag | @UNLOGGED_ERROR_PROCESS_FLAG
					WHERE CURRENT OF ProcessFiles_Files_cur

					SELECT @log_desc = isNull(@log_desc, '') + @file_dir + @file_name + '; '
							+ 'ProcessFlag = ' + convert(varchar, ProcessFlag)
						FROM #FileDetail det JOIN #FilePath path ON det.FilePathId = path.id
							JOIN #FileDir dir ON path.FileDirId = dir.id
							WHERE ProcessFlag = 0 
								AND Dir = @file_dir
								AND FileName = @file_name
					EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name,
									@AgentName = @proc_name,
									@Statement = @stmnt_lastexec,
									@RecordCount = @rcnt,
									@LogDesc = 	@log_desc,
									@UserId = NULL,
									@IsWarnOnly = 1
					SET @log_desc = ''
				END
			END
		END
		CLOSE ProcessFiles_Files_cur
		DEALLOCATE ProcessFiles_Files_cur
		UPDATE #FileDetail SET ProcessFlag = @SKIPPED_PROCESS_FLAG
			WHERE 	--is_file = 1
				convert (datetime, cast(LastWrittenDate as varchar(20)), 112)
					>= dateAdd(dd, @DaysOld * -1, getDate())
		SELECT @log_desc = 'Statistics: ' + CHAR(10)
			+ 'TOTAL: ' 	+ convert(varchar, count(*)) + CHAR(10) 
			+ 'ERROR: '	+ convert(varchar, sum(ProcessFlag & @ERROR_PROCESS_FLAG)/@ERROR_PROCESS_FLAG) + CHAR(10)
			+ 'UNLOGGED_ERROR: '	+ convert(varchar, sum(ProcessFlag & @UNLOGGED_ERROR_PROCESS_FLAG)/@UNLOGGED_ERROR_PROCESS_FLAG) + CHAR(10)
			+ 'SUCCESS: '	+ convert(varchar, sum(ProcessFlag & @SUCCESS_PROCESS_FLAG)/@SUCCESS_PROCESS_FLAG) + CHAR(10)
			+ 'DELETED: '	+ convert(varchar, sum(ProcessFlag & @DELETED_PROCESS_FLAG)/@DELETED_PROCESS_FLAG) + CHAR(10)
			+ 'SKIPPED: '	+ convert(varchar, sum(ProcessFlag & @SKIPPED_PROCESS_FLAG)/@SKIPPED_PROCESS_FLAG)
			FROM #FileDetail 
--SELECT * FROM #FileDetail 
	
		EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name,
						@AgentName = @proc_name,
						@Statement = '',--@stmnt_lastexec,
						@RecordCount = @rcnt,
						@LogDesc = 	@log_desc,
						@UserId = NULL,
						@IsLogOnly = 1
		SET @log_desc = ''
	END	--IF @FileCommand IS NOT NULL BEGIN
--SELECT 'going to email...'

	IF @PostCommand IS NOT NULL BEGIN
		SELECT @cmd = replace(@PostCommand, '{dir}', @Dir)
		SELECT @log_desc = @cmd 
		SELECT 	@stmnt_lastexec = "EXEC sp_executesql @cmd, N'@err int OUTPUT', @err OUTPUT"
		EXEC sp_executesql @cmd, N'@err int OUTPUT', @err OUTPUT 
		IF (@err <> 0) GOTO Err
	END 	--IF @PostCommand IS NOT NULL BEGIN

	GOTO Email
	
ErrCloseCurFileDetails:
	CLOSE ProcessFileDetails_cur
	DEALLOCATE ProcessFileDetails_cur
	GOTO Err

ErrCloseCurFiles: 
	CLOSE ProcessFiles_Files_cur
	DEALLOCATE ProcessFiles_Files_cur

Err:
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
					@AgentName = @proc_name,
					@Statement = @stmnt_lastexec, 
					@ErrCode = @err, 
					@RecordCount = @rcnt, 
					@LogDesc = @log_desc,
					@EMNotify = NULL, 
					@UserId = NULL

Email:
	-- no error handling here - we prefer to get back a real error
	EXEC ADM_MAIL_CURSPROC_SQL_ERR_LOG @SystemName = @db_name,
					@AgentName = @proc_name,
					@StatementBeg = '/**** Input parameters ****/',
					@EmailList = @EmailList,
					@WarnLevel = 0,
					@Action = @EmailSubjAction
--end
	RETURN @err
END
GO


