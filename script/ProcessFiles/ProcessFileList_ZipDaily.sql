   SET QUOTED_IDENTIFIER OFF
IF OBJECT_ID('ProcessFileList_ZipDaily') IS NOT NULL  
  DROP PROCEDURE ProcessFileList_ZipDaily
GOCREATE PROCEDURE ProcessFileList_ZipDaily @SourceDir nvarchar (500), --with ending '\'
		@TargetDir$ZipFilePrefix nvarchar (500), @Recurs bit, @Move bit = 0, @SkipToday bit = 0 AS

/**********************************************************************
Use as parameter of 
ProcessFiles @FileListCommand = 'EXEC @err = ProcessFiles_ZipDaily @TargetDir$ZipFilePrefix = ''D:\SQLArchive\SQLBackup_'''

used zip.exe options:
-r 
Travel the directory structure recursively; for example: 
zip -r foo foo 
-t mmddyyyy 
Do not operate on files modified prior to the specified date, where mm is the month (0-12), dd is the day of the month (1-31), and yyyy is the year. The ISO 8601 date format yyyy-mm-dd is also accepted. For example: 
zip -rt 12071991 infamy foo 
zip -rt 1991-12-07 infamy foo 
will add all the files in 
foo and its subdirectories that were last modified on or after 7 December 1991, to the zip archive infamy.zip. 
-tt mmddyyyy 
Do not operate on files modified after or at the specified date, where mm is the month (0-12), dd is the day of the month (1-31), and yyyy is the year. The ISO 8601 date format yyyy-mm-dd is also accepted. For example: 
zip -rtt 11301995 infamy foo 
zip -rtt 1995-11-30 infamy foo 
will add all the files in 
foo and its subdirectories that were last modified before the 30 November 1995, to the zip archive infamy.zip. 
-u 
Replace (update) an existing entry in the zip archive only if it has been modified more recently than the version already in the zip archive. For example: 
zip -u stuff * 
will add any new files in the current directory, 
and update any files which have been modified since the zip archive stuff.zip was last created/modified (note that zip will not try to pack stuff.zip into itself when you do this). 


convert
21 or 121 (*)  ODBC canonical (with milliseconds) yyyy-mm-dd hh:mi:ss.mmm(24h) 

TEST:

ProcessFiles_v2	@Dir = 'W:\RAC\SQLAdmin\ZipCopy\test\src',
--		@PreCommand nvarchar(4000) = NULL,
--		@FileDetailsCommand nvarchar(4000) = NULL,
		@FileListCommand = 'EXEC @err = ProcessFileList_ZipDaily @SourceDir = ''{dir}'', @TargetDir$ZipFilePrefix = ''W:\RAC\SQLAdmin\ZipCopy\test\src'', @Recurs = {recurs}, @Move = 1', 	
--	@FileCommand nvarchar(4000) = NULL,
--	@PostCommand nvarchar(4000) = NULL,
--	@FileMaskList nvarchar(1000) = '%',		--(list, ":" delimited), only '%' symbols for zipping 
--	@ExceptFileMaskList nvarchar(1000),			-- ('_' will not work)
	@Recurs = 1,
--	@DaysOld int =  0,
	@EmailList = 'victor@michaeljoubert.com',
	@EmailSubjAction = 'ZipDaily-local test'

SELECT TOP 100 * FROM SQL_ERR_LOG ORDER BY ErrId DESC



MODIFICATIONS:
vic123, 070109, added '"' around @SourceDir and @target
vic123, 070323, added @Move argument
vic123, 070330, added @SkipToday argument
*********************************************************************/

BEGIN

	DECLARE @proc_name sysname, @db_name sysname    			--used for unified calling of ADM_WRITE_SQL_ERR_LOG
	SELECT @proc_name = name, @db_name = db_Name() 
		FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int			--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @log_desc nvarchar(4000)			-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------

	DECLARE @maxdate datetime, @mindate datetime
	SELECT @stmnt_lastexec = "SELECT 	@maxdate = max(dbo.IntDT2DT(LastWrittenDate, LastWrittenTime)),...."
	SELECT 	@maxdate = max(dbo.IntDT2DT(LastWrittenDate, LastWrittenTime)),
		@mindate = min(dbo.IntDT2DT(LastWrittenDate, LastWrittenTime))
		FROM #FileDetail
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF @err <> 0 GOTO Err

	DECLARE @ZIP_EXE nvarchar(4000)
	SELECT @stmnt_lastexec = "SELECT @ZIP_EXE = 'zip.exe -r -t{start_YYYY-MM-DD} -tt{break_YYYY-MM-DD} -u {target}'..."
	SELECT @ZIP_EXE = 'D:\SQLAdmin\bin\zip.exe -t {start_YYYY-MM-DD} -tt {break_YYYY-MM-DD}'
			+ CASE @Move WHEN 1 THEN ' -m ' ELSE ' ' END
			+ CASE @Recurs WHEN 1 THEN ' -r ' ELSE ' ' END
			+ ' -u {target}'
			+ ' "' + @SourceDir + replace(nstr, '%', '*') + '"' FROM #FileMask
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF @err <> 0 GOTO Err

	SELECT @stmnt_lastexec = "SELECT @ZIP_EXE = @ZIP_EXE ...."
	SELECT @ZIP_EXE = @ZIP_EXE 
			+ ' -x ' + replace(nstr, '%', '*') 
			+ ' 2>&1'
		FROM #ExceptFileMask
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF @err <> 0 GOTO Err


	CREATE TABLE #ZipOut	(id int IDENTITY, 
				nstr nvarchar(4000)
		)

	DECLARE FileDetail_date_cur CURSOR FOR 
		SELECT DISTINCT LastWrittenDate
			FROM #FileDetail
		ORDER BY LastWrittenDate
	DECLARE @int_date int, @zip_date datetime, @char_date varchar(30), @target nvarchar(500)

	OPEN FileDetail_date_cur
	WHILE (1 = 1) BEGIN
		FETCH NEXT FROM FileDetail_date_cur INTO @int_date
		IF (@@FETCH_STATUS <> 0) BREAK		

		--skip today to avoid conflicts with other active processes
		IF (@SkipToday = 1 AND @int_date = dbo.DT2IntDate(getdate())) CONTINUE 
--modified: otherwise daily overwriting backups are not archived

		SELECT @zip_date = dbo.IntDT2DT(@int_date, 0)
		SELECT @char_date = left(convert(varchar, @zip_date, 121), 10)
		
		DECLARE @cmd nvarchar(4000)
		SELECT @cmd = replace(@ZIP_EXE, '{start_YYYY-MM-DD}', @char_date)

		SELECT @zip_date = dateAdd(dd, 1, @zip_date)
		SELECT @char_date = left(convert(varchar, @zip_date, 121), 10)
		SELECT @cmd = replace(@cmd, '{break_YYYY-MM-DD}', @char_date)

		SELECT @target = '"' + @TargetDir$ZipFilePrefix + '_' + convert(varchar, @int_date) + '"' 
		SELECT @cmd = replace(@cmd, '{target}', @target)

		DELETE #ZipOut
		----->>>EXEC HERE>>>>>
--SELECT @cmd
		SELECT @stmnt_lastexec = "EXEC @err = master.dbo.xp_cmdshell @cmd",
			@log_desc = @cmd
		INSERT INTO #ZipOut (nstr)
			EXEC @err = master.dbo.xp_cmdshell @cmd
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT

		DELETE #ZipOut WHERE nstr IS NULL
		DECLARE @zip_out nvarchar(4000)	
		SET @zip_out = NULL
--SELECT * FROM #ZipOut
		SELECT @zip_out = isNull(@zip_out + CHAR(10), '') + isNull(nstr, '') 
			FROM #ZipOut

		DECLARE @is_log int, @is_warn int
		SELECT 	@is_log = 1, @is_warn = 0
		IF @err = 12 SET @err = 0 --12 zip has nothing to do
		IF (@err <> 0) BEGIN
			SELECT 	@is_log = 0, @is_warn = 1
		END 
		SELECT @log_desc = isNull(@log_desc + '; ',  '') + isNull(CHAR(10) + @zip_out, '')
--SELECT @zip_out, @err
		IF ((@zip_out IS NOT NULL) OR @err <> 0) BEGIN
			EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name,
							@AgentName = @proc_name,
							@Statement = @stmnt_lastexec,
							@ErrCode = @err, 
							@RecordCount = @rcnt,
							@LogDesc = 	@log_desc,
							@UserId = NULL,
							@IsLogOnly = @is_log,
							@IsWarnOnly = @is_warn
		END	--IF @log_desc IS NOT NULL BEGIN
	END 	--OPEN FileDetail_date_cur
	CLOSE FileDetail_date_cur
	DEALLOCATE FileDetail_date_cur

	RETURN 0
ErrCloseCur:
	CLOSE FileDetail_date_cur
	DEALLOCATE FileDetail_date_cur
	GOTO Err

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


