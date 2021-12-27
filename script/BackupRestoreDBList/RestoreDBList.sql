
SET QUOTED_IDENTIFIER OFF
GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[RestoreDBList]') 
		AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[RestoreDBList]
GO
CREATE PROCEDURE RestoreDBList	 	@DBList 	nvarchar(1000), 
					@FilePrefixList 	nvarchar(1000) = NULL, 
					@BackupDir 	nvarchar(500), --may contain or not ending '\',
					@DataDir 	nvarchar(500), --may contain or not ending '\',
					@DoRecover 	bit = 1, 
					@EmailList	varchar(500) = NULL, --separated by ','
					@ListDelimiter nvarchar(10) = ',',
					@LogToSQLAdmin 	bit = 1

--				@DoSyncWithBackup bit = 0
--SET QUOTED_IDENTIFIER OFF
--DROP PROCEDURE [dbo].[RestoreDBList]
/**********************************************************************************************
Procedure Name	: RestoreDBList
Author		: Victor Blokhin (vic123.com)
Date		: May 2007
Purpose		: Resore full and log of several databases with emailing of results. 
			Backup file name should be of form *_full|log|diff.bak|zip
Referred	: StringListToTable function, ErrLog module
Description	: Restores list of databases from files with corresponding prefixes
automatically restores last full and any number of subsequent log backups, unzips them if necessary, logs and emails warnings and errors
**********************************************************************************************/
/*MODIFICATIONS HISTORY IN CHRONOLOGICAL ORDER, WITH THE LATEST CHANGE BEING AT THE TOP.*/ 
/******************************************************************************************** 
MODIFIED BY      : 	Victor Blokhin 
MODIFICATIONS    :	
DATE             :	

*********************************************************************************************/
/******************************************************************************************** 
TEST


Billing_20070529_040003_full.bak 
W:\SQLAdmin\Backup\RestoreDBList_test\Billing_20070529_040003_full.bak 
W:\SQLAdmin\Backup\RestoreDBList_test\
SQLAdmin_20070529_030003_full.bak 

EXEC RestoreDBList @DBList = 'Billing_RestoreDBListTest, SQLAdmin__RestoreDBListTest',
				@FilePrefixList = 'Billing_, SQLAdmin', 
				@BackupDir = 'W:\SQLAdmin\Backup\RestoreDBList_test\',	
				@DataDir = 'I:\SQLData\LAT1',
				@DoRecover = 0, 
				@EmailList	= 'victor@michael.com',
				@ListDelimiter = ','

EXEC RestoreDBList @DBList = 'SQLAdmin__RestoreDBListTest',
				@FilePrefixList = 'SQLAdmin', 
				@BackupDir = 'W:\SQLAdmin\Backup\RestoreDBList_test\',	
				@DataDir = 'I:\SQLData\LAT1',
				@DoRecover = 0, 
				@EmailList	= 'victor@michael.com',
				@ListDelimiter = ','



EXEC RestoreDBList @DBList = 'dfdf,SQAD', 
			@BackupDir = 'I:\SQLData\LAT1_Bak' , --may contain or not ending '\'
			@BackupType = 'FULL', --|'LOG'|'DIFF'
			@EmailList = 'victor@infoplanet-usa.com,vic@infoplanet-usa.com', --separated by ','
			@ListDelimiter = ','--,

SELECT * FROM SQL_ERR_LOG

EXEC BackupDBList @DBList = 'SQLAdmin,master', 
			@BackupDir = 'I:\SQLData\LAT1_Bak' , --may contain or not ending '\'
			@BackupType = 'FULL', --|'LOG'|'DIFF'
			@EmailList = 'victor@infoplanet-usa.com,vic@infoplanet-usa.com', --separated by ','
			@ListDelimiter = ','--,

EXEC BackupDBList @DBList = 'SQLAdmin', 
			@BackupDir = 'I:\SQLData\LAT1_Bak' , --may contain or not ending '\'
			@BackupType = 'LOG', --|'LOG'|'DIFF'
			@EmailList = 'victor@infoplanet-usa.com,vic@infoplanet-usa.com', --separated by ','
			@ListDelimiter = ','--,


***********************************/
AS BEGIN
--declare a set of standard error logging variables
	DECLARE @proc_name sysname				--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	DECLARE @db_name sysname				-- ----""------
	SELECT 	@proc_name = name, @db_name = db_Name() 
		FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int				--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @log_desc nvarchar(1000)			-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)	-- 		----""------
	DECLARE @err_fin int			--for emailing of both success and error flow control

	--log input parameters, it is a valuable info
	SELECT @proc_name = name,
			@db_name = db_Name()
		FROM sysobjects WHERE id = @@PROCID	
	if (@LogToSQLAdmin = 1) begin
		SELECT @stmnt_lastexec =   'Input parameters'
		SELECT @log_desc = 	CHAR(10)
					+ '@DBList nvarchar(1000): ' + isNull('''' + @DBList + '''', 'NULL') + CHAR(10)
					+ '@FilePrefixList nvarchar(1000): ' + isNull('''' + @FilePrefixList + '''', 'NULL') + CHAR(10)
					+ '@BackupDir nvarchar(500): ' + isNull('''' + @BackupDir + '''', 'NULL') + CHAR(10)
					+ '@DataDir nvarchar(500): ' + isNull('''' + @DataDir + '''', 'NULL') + CHAR(10)
					+ '@DoRecover bit: ' + isNull(convert (varchar, @DoRecover), 'NULL') + CHAR(10)
					+ '@EmailList varchar(500): ' + isNull('''' + @EmailList + '''', 'NULL') + CHAR(10)
					+ '@ListDelimiter nvarchar(10): ' + isNull('''' + @ListDelimiter + '''', 'NULL')
		EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
						@AgentName = @proc_name,
						@Statement = @stmnt_lastexec,
						@RecordCount = @rcnt,
						@LogDesc = @log_desc,
						@IsLogOnly = 1
		SET @log_desc = ''
	end
	
	--convert input DB list into table
	SELECT @stmnt_lastexec = "SELECT * INTO #DB2Restore FROM StringListToTable (@DBList, @ListDelimiter)"
	SELECT *, convert(nvarchar(500), '') AS FilePrefix INTO #DB2Restore FROM StringListToTable (@DBList, @ListDelimiter)
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

--SELECT * FROM StringListToTable (NULL, ',')
	--convert input FilePrefixList into table
	SELECT @stmnt_lastexec = "SELECT * INTO #FilePrefix2Restore FROM StringListToTable (@FilePrefixList, @ListDelimiter)"
	SELECT * INTO #FilePrefix2Restore FROM StringListToTable (@FilePrefixList, @ListDelimiter)
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

--	SELECT @stmnt_lastexec = "ALTER TABLE #DB2Restore ADD FilePrefix nvarchar(500)"
--	ALTER TABLE #DB2Restore ADD FilePrefix nvarchar(500)
--	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
--	IF (@err <> 0) GOTO Err

	SELECT @stmnt_lastexec = "UPDATE dbr SET dbr.FilePrefix = isNull(frp.nstr, dbr.nstr)..."
	UPDATE dbr SET dbr.FilePrefix = isNull(fpr.nstr, dbr.nstr)
		FROM #DB2Restore dbr LEFT JOIN #FilePrefix2Restore fpr ON dbr.listpos = fpr.listpos
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

select * from #DB2Restore
	--step over databases
	SELECT @stmnt_lastexec = "DECLARE RestoreDBs_cur CURSOR FOR SELECT nstr FROM #DB2Restore..."
	DECLARE RestoreDBs_cur CURSOR FOR SELECT nstr, FilePrefix FROM #DB2Restore
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

--	CREATE TABLE #FileList (id int identity(1,1), BackupFilename nvarchar(500))
	CREATE TABLE #CmdShellOut (id int IDENTITY, nstr nvarchar(4000))
	
	CREATE TABLE #FileListOutput (LogicalName nvarchar(128),           -- Logical name of the file 
                              PhysicalName nvarchar(260),          -- Physical or operating-system name of the file 
                              Type char(1),                        -- Data file (D) or a log file (L) 
                              FileGroupName nvarchar(128) NULL,    -- Name of the filegroup that contains the file 
                              Size numeric(20,0) NULL,             -- Current size in bytes 
                              MaxSize numeric(20,0) NULL,          -- Maximum allowed size in bytes 
                              RowNum int identity(1,1))     

	DECLARE @rest_db_name sysname, @fileprefix nvarchar(500), @cmd nvarchar(4000), @file_id int, @filename nvarchar(500)
	DECLARE @backup_path nvarchar(500), @sql nvarchar(4000), @move_arg nvarchar(1000), @d_count int, @l_count int


	IF (right(@BackupDir, 1) <> '\') SET @BackupDir = @BackupDir + '\'
	IF (right(@DataDir, 1) <> '\') SET @DataDir = @DataDir + '\'

	OPEN RestoreDBs_cur
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

	WHILE (1=1) BEGIN
		SELECT @stmnt_lastexec = "FETCH NEXT FROM RestoreDBs_cur INTO @rest_db_name, @fileprefix ..."
		FETCH NEXT FROM RestoreDBs_cur INTO @rest_db_name, @fileprefix 
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err_RestoreDBs_cur

		IF (@@FETCH_STATUS <> 0) BREAK
		
		SELECT @cmd = 'dir /o /b ' + @BackupDir + @fileprefix + '*'
SELECT @cmd 
		SELECT @stmnt_lastexec = "EXEC @err = ExecXPCmdShell 	@Cmd = @cmd, @DBName = @db_name, @ProcName = @proc_name"
		EXEC @err = ExecXPCmdShell 	@Cmd = @cmd, @DBName = @db_name, @ProcName = @proc_name
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err_RestoreDBs_cur

		DELETE FROM #CmdShellOut WHERE nstr IS NULL
select * from #CmdShellOut

	--find and restore last full backup 
		SELECT @stmnt_lastexec = "SELECT @file_id = id, @filename = nstr ..."
		SELECT @file_id = id, @filename = nstr FROM #CmdShellOut
		WHERE nstr = (SELECT max(nstr) FROM #CmdShellOut cso1 WHERE nstr LIKE '%\_full.%' ESCAPE '\')
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err_RestoreDBs_cur
		IF @rcnt = 0 SET @file_id = 0
		ELSE BEGIN
			IF right(@filename, 4) = '.zip' BEGIN
				IF NOT EXISTS (SELECT * FROM #CmdShellOut 
						WHERE nstr = replace(@filename, '.zip', '.bak'))
				BEGIN
					SELECT @stmnt_lastexec = "EXEC @err = ProcessFiles_UnZip_7Zip @ZipDir = @BackupDir, @ZipFileName = @filename", 
								@err = NULL
					EXEC @err = ProcessFiles_UnZip_7Zip @ZipDir = @BackupDir, @ZipFileName = @filename
					SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
					IF (@err <> 0) GOTO Err_RestoreDBs_cur
				END
				SELECT @filename = replace(@filename, '.zip', '.bak')
			END
			SET @backup_path = @BackupDir + @filename
	
			SELECT @sql = 'RESTORE FILELISTONLY FROM DISK=''' + @BackupDir + @filename + ''''
			SELECT @stmnt_lastexec = "INSERT #FileListOutput EXEC @err = sp_executesql @sql", 
						@log_desc = @sql,
						@err = NULL
		        INSERT #FileListOutput EXEC @err = sp_executesql @sql
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err_RestoreDBs_cur
select * from #FileListOutput	
	
		        SELECT  @move_arg = NULL, @d_count = NULL, @l_count = NULL
	
		        SELECT  @move_arg = ISNULL(@move_arg + ', ' , '') + 'MOVE ''' + rtrim(LogicalName) + ''' TO ''' 
	                		+ CASE WHEN Type = 'D' 
						THEN @DataDir + @rest_db_name + '_data' 
	                         			+ CASE WHEN PhysicalName LIKE '%.MDF' THEN '.MDF' 
								ELSE convert(varchar(2), isnull(@d_count,0)+1) + '.NDF' 
								END
	                                    	WHEN Type = 'L'
	                                    	THEN @DataDir  + @rest_db_name + '_log' 
	                                         + CASE WHEN @l_count >= 1 
							THEN convert(varchar(2), @l_count+1) ELSE '' END + '.LDF'
	                               		END + '''',
	                	@d_count = isnull(@d_count,0) + CASE WHEN Type = 'D' THEN 1 ELSE 0 END,
	                	@l_count = isnull(@l_count,0) + CASE WHEN Type = 'L' THEN 1 ELSE 0 END
		          FROM  #FileListOutput
	
			SELECT @sql = 'RESTORE DATABASE ' + @rest_db_name 
					+ ' FROM DISK= ''' + @BackupDir + @filename + ''' ' 
					+ ' WITH ' + @move_arg + ' , STANDBY = ''' + @DataDir  + @rest_db_name + '.standby'''
SELECT @sql
			SELECT @stmnt_lastexec = "EXEC @err = sp_executesql @sql",
						@log_desc = @sql,
						@err = NULL
		        EXEC @err = sp_executesql @sql
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err_RestoreDBs_cur

		END--find and restore last full backup 

	-- Locate and restore last DIFF backup
		SELECT @stmnt_lastexec = "SELECT @file_id = id, @filename = nstr ..."
--test
--DECLARE @file_id int
--SELECT @file_id = 1
--SELECT @file_id = 3 from sysobjects where name like 'dsfsdfd'
--SELECT @file_id 

		SELECT @file_id = id, @filename = nstr 
			FROM #CmdShellOut 
			WHERE nstr = (SELECT max(nstr) FROM #CmdShellOut cso1 
				WHERE nstr LIKE '%\_diff.%' ESCAPE '\') 
			AND id > @file_id
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err_RestoreDBs_cur
		IF @rcnt <> 0 BEGIN
			IF right(@filename, 4) = '.zip' BEGIN
				IF NOT EXISTS (SELECT * FROM #CmdShellOut 
						WHERE nstr = replace(@filename, '.zip', '.bak'))
				BEGIN
					SELECT @stmnt_lastexec = "EXEC @err = ProcessFiles_UnZip_7Zip @ZipDir = @BackupDir, @ZipFileName = @filename", 
								@err = NULL
					EXEC @err = ProcessFiles_UnZip_7Zip @ZipDir = @BackupDir, @ZipFileName = @filename
					SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
					IF (@err <> 0) GOTO Err_RestoreDBs_cur
				END
				SELECT @filename = replace(@filename, '.zip', '.bak')
			END

			SELECT @sql = 'RESTORE DATABASE ' + @rest_db_name 
					+ ' FROM DISK= ''' + @BackupDir + @filename + ''' ' 
					+ ' WITH ' + ' STANDBY = ''' + @DataDir  + @rest_db_name + '.standby'''

			SELECT @stmnt_lastexec = "EXEC @err = sp_executesql @sql",
						@log_desc = @sql,
						@err = NULL
		        EXEC @err = sp_executesql @sql
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err_RestoreDBs_cur
		END

	-- process tran logs

		DECLARE CmdShellOut_cur CURSOR FOR 
			SELECT 	--@file_id = id, 
				nstr 
				FROM #CmdShellOut
				WHERE nstr LIKE '%\_log.%' ESCAPE '\'
					AND id > @file_id
				ORDER BY id
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err_CmdShellOut_cur
	
		OPEN CmdShellOut_cur
		WHILE (1 = 1) BEGIN
			FETCH NEXT FROM CmdShellOut_cur INTO @filename
			IF (@@FETCH_STATUS <> 0) BREAK
			IF right(@filename, 4) = '.zip' BEGIN
				IF NOT EXISTS (SELECT * FROM #CmdShellOut 
						WHERE nstr = replace(@filename, '.zip', '.bak'))
				BEGIN
					SELECT @stmnt_lastexec = "EXEC @err = ProcessFiles_UnZip_7Zip @ZipDir = @BackupDir, @ZipFileName = @filename", 
								@err = NULL
					EXEC @err = ProcessFiles_UnZip_7Zip @ZipDir = @BackupDir, @ZipFileName = @filename
					SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
					IF (@err <> 0) GOTO Err_CmdShellOut_cur
				END
				SELECT @filename = replace(@filename, '.zip', '.bak')
			END
	
			SELECT @sql = 'RESTORE LOG ' + @rest_db_name 
					+ ' FROM DISK= ''' + @BackupDir + @filename + ''' ' 
					+ ' WITH ' + ' STANDBY = ''' + @DataDir  + @rest_db_name + '.standby'''
	
			SELECT @stmnt_lastexec = "EXEC @err = sp_executesql @sql",
						@log_desc = @sql,
						@err = NULL
		        EXEC @err = sp_executesql @sql
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err_CmdShellOut_cur
		END-- process tran logs
		CLOSE CmdShellOut_cur
		DEALLOCATE CmdShellOut_cur

		IF @DoRecover = 1 BEGIN
			SELECT @sql = 'RESTORE DATABASE ' + @rest_db_name + ' WITH RECOVERY'
			SELECT @stmnt_lastexec = "EXEC @err = sp_executesql @sql",
						@log_desc = @sql,
						@err = NULL
		        EXEC @err = sp_executesql @sql
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err_CmdShellOut_cur
		END
		DELETE FROM #CmdShellOut
		DELETE FROM #FileListOutput	
	END--RestoreDBs_cur
	CLOSE RestoreDBs_cur
	DEALLOCATE RestoreDBs_cur


	
	SET @err_fin = 0

	GOTO Email

Err_CmdShellOut_cur:
	CLOSE CmdShellOut_cur
	DEALLOCATE CmdShellOut_cur

Err_RestoreDBs_cur:
	CLOSE RestoreDBs_cur
	DEALLOCATE RestoreDBs_cur

Err:
	if (@LogToSQLAdmin = 1) begin
		EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
								@AgentName = @proc_name,
								@Statement = @stmnt_lastexec, 
								@ErrCode = @err, 
								@RecordCount = @rcnt, 
								@LogDesc = @log_desc,
								@EMNotify = NULL, 
								@UserId = NULL
	end else raiserror(@log_desc, 16, 1)

	SET @err_fin = @err

Email:
	SELECT @stmnt_lastexec = "EXEC @err = ADM_MAIL_CURSPROC_SQL_ERR_LOG @SystemName = @db_name,..."
	if (@EmailList is not null) begin
		EXEC @err = ADM_MAIL_CURSPROC_SQL_ERR_LOG @SystemName = @db_name,
							@AgentName = @proc_name,
							@StatementBeg = 'Input parameters',
							@EmailList = @EmailList,
							@WarnLevel = 0
	end
	IF (@err <> 0) GOTO Err_Final
	RETURN @err_fin

Err_Final:
	if (@LogToSQLAdmin = 1) begin
		EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
							@AgentName = @proc_name,
							@Statement = @stmnt_lastexec, 
							@ErrCode = @err, 
							@RecordCount = @rcnt, 
							@LogDesc = @log_desc,
							@EMNotify = @EmailList, 
							@UserId = NULL
	end else raiserror(@log_desc, 16, 1)
	RETURN @err_fin
END
GO



SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO



