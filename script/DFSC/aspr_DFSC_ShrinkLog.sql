SET QUOTED_IDENTIFIER OFF
GO
DROP PROCEDURE aspr_DFSC_ShrinkLog
GO
CREATE PROCEDURE aspr_DFSC_ShrinkLog	@DefLogShrinkThresholdMB bigint = NULL, 
										@DBLogsShrinkThresholdsMB varchar(2000) = NULL,
										@ShrinkLogOnLowSpaceOnly bit = 1,
										@LogNotifyOnly bit = 0

AS BEGIN

	DECLARE @proc_name sysname					--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	SELECT @proc_name = name FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int					--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @logmsg nvarchar(255)				-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------

	SELECT 	@stmnt_lastexec = "CREATE TABLE #DFSC_ShrinkLog_logspace	(..."
	CREATE TABLE #DFSC_ShrinkLog_logspace	(
			Dbname sysname,
			LogSizeMB decimal(18,3),
			LogUsedPercent decimal(18,3),
			Status int,
			ShrinkThreshold	int
--todo:			CanGrow, warning if no
		)
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	SELECT 	@stmnt_lastexec = "	INSERT #DFSC_ShrinkLog_logspace (Dbname, LogSizeMB, LogUsedPercent, Status)"
	INSERT #DFSC_ShrinkLog_logspace (Dbname, LogSizeMB, LogUsedPercent, Status)
		EXEC ('DBCC SQLPERF(LOGSPACE)')
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	SELECT 	@stmnt_lastexec = "SELECT str1 DB, str2 Limit INTO #DFSC_ShrinkLog_shrink_thresh"
	SELECT str1 DBName, str2 ShrinkThreshold INTO #DFSC_ShrinkLog_shrink_thresh
	FROM aspr_Iter2CharListToTable(@DBLogsShrinkThresholdsMB, '::') 
	ORDER BY str1
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	DECLARE @missing_dbs nvarchar(1000)
	SELECT @missing_dbs = isNull(@missing_dbs + ', ',  '') + DBName 
		FROM #DFSC_ShrinkLog_shrink_thresh st
		WHERE NOT EXISTS (SELECT * FROM #DFSC_ShrinkLog_logspace ls
							WHERE st.DBName = ls.DBName)

	IF (@missing_dbs IS NOT NULL) BEGIN
		SELECT @missing_dbs = 'Databases ' + @missing_dbs + ' does not exist on the server'
		EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'DMDBA', 
								@AgentName = @proc_name,
								@Statement = 'IF (@missing_dbs IS NOT NULL) BEGIN...',
								@RecordCount = 0,
								@LogDesc = 	@missing_dbs,
								@UserId = NULL, 
								@IsWarnOnly = 1
		SELECT 	@stmnt_lastexec = "		EXEC @err = aspr_DFSC_AddEmail 	@Subject = @missing_dbs, ..."
		EXEC @err = aspr_DFSC_AddEmail 	@Subject = @missing_dbs, 
						@WarnLevel = 4,
						@Body = NULL
		SELECT @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err 
	END

	UPDATE #DFSC_ShrinkLog_shrink_thresh SET ShrinkThreshold = NULL
	WHERE ShrinkThreshold = ''

	UPDATE ls SET ShrinkThreshold = isNull(st.ShrinkThreshold, @DefLogShrinkThresholdMB)
	FROM #DFSC_ShrinkLog_logspace ls LEFT JOIN #DFSC_ShrinkLog_shrink_thresh st
		ON st.DBName = ls.DBName

	DECLARE @log_space_info varchar(4000)
	SELECT 	@stmnt_lastexec = "EXEC @err = aspr_DFSC_LogSpaceInfo2Str @drives_space_info OUT"
	EXEC @err = aspr_DFSC_LogSpaceInfo2Str @log_space_info OUT
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'DMDBA', 
							@AgentName = @proc_name,
							@Statement = '/**** Initial Log Data ****/',
							@RecordCount = @rcnt,
							@LogDesc = 	@log_space_info,
							@UserId = NULL, 
							@IsLogOnly = 1

	SELECT 	@stmnt_lastexec = "CREATE TABLE #aspr_DFSC_ShrinkLog_sysfiles	(..."
	CREATE TABLE #aspr_DFSC_ShrinkLog_sysfiles	(
				fileid 		smallint,
				groupid		smallint,
				size		int,
				maxsize		int,
				growth		int,
				status		int,
				perf		int,
				name 		nchar(128),
				filename	nchar(260),
				DoShrink	bit 
		)
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	DECLARE DFSC_ShrinkLog_logspace_cur CURSOR FOR 
			SELECT DBName, ShrinkThreshold FROM #DFSC_ShrinkLog_logspace 
					WHERE LogSizeMB > ShrinkThreshold
	DECLARE @dbname sysname, @sh_th int
	OPEN DFSC_ShrinkLog_logspace_cur
	WHILE (1=1) BEGIN 
		FETCH NEXT FROM DFSC_ShrinkLog_logspace_cur INTO @dbname, @sh_th
		IF (@@FETCH_STATUS <> 0) BREAK
		DECLARE @sql nvarchar(4000)
		SELECT @sql = 	N'INSERT INTO #aspr_DFSC_ShrinkLog_sysfiles (' + CHAR(10)  
						+ '			fileid, groupid, size, maxsize, growth, status, ' + CHAR(10) 
						+ '			perf, name, filename)' + CHAR(10)  
						+ '		SELECT fileid, groupid, size, maxsize, growth, status, ' + CHAR(10) 
						+ '				perf, name, filename' + CHAR(10)  
						+ '		FROM ' + @dbname + '.dbo.sysfiles ' + CHAR(10) 
						+ ' 	WHERE (status & 0x40) <> 0'
		SELECT 	@stmnt_lastexec = "exec @err = sp_executesql 'INSERT INTO #aspr_DFSC_ShrinkLog_sysfiles ..."
		exec @err = sp_executesql @sql
		IF (@err <> 0) GOTO Err_logspace_cur

		DECLARE DFSC_ShrinkLog_sysfiles_cur CURSOR FOR 
			SELECT rTrim(name) as LogFileName, left(filename,1) AS LogDrive
			FROM #aspr_DFSC_ShrinkLog_sysfiles 
			WHERE Status & 0x40 <> 0
		DECLARE @log_file_name sysname, @logfile_drive char(1)
		OPEN DFSC_ShrinkLog_sysfiles_cur
		WHILE (1=1) BEGIN
			FETCH NEXT FROM DFSC_ShrinkLog_sysfiles_cur 
				INTO @log_file_name, @logfile_drive
			IF (@@FETCH_STATUS <> 0) BREAK

			DECLARE @freespace_limit_diff bigint
			SELECT @freespace_limit_diff = FreeSpaceMB - FreeLimitMB
				FROM #DrivesFreeSpaceControl_drives WHERE Drive = @logfile_drive
			SELECT @freespace_limit_diff = isNull(@freespace_limit_diff, 0)
	
			IF (@LogNotifyOnly = 0 AND (@ShrinkLogOnLowSpaceOnly = 0 OR @freespace_limit_diff < 0)) BEGIN
				SELECT 	@stmnt_lastexec = "EXEC aspr_DFSC_AddEmail 	@Subject = 'Initial Log Data', ..."
				EXEC @err = aspr_DFSC_AddEmail 	@Subject = 'Initial Log Data', 
								@WarnLevel = 1,
								@Body = @log_space_info
				SELECT @rcnt = @@ROWCOUNT
				IF (@err <> 0) GOTO Err_sysfiles_cur

				IF (@sh_th = 0) BEGIN --truncate log
					SELECT 	@stmnt_lastexec = "BACKUP LOG @dbname WITH TRUNCATE_ONLY"
					--!! incompatible with SQL 2008
					--!!BACKUP LOG @dbname WITH TRUNCATE_ONLY
					raiserror ('BACKUP LOG @dbname WITH TRUNCATE_ONLY statement is incompatible with SQL 2008 and temporary disabled', 10, 1)
					SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
					IF (@err <> 0) GOTO Err_sysfiles_cur
				END
				SELECT @sql = 	'USE ' + @dbname + CHAR(10)
								+ 'DBCC SHRINKFILE(''' + @log_file_name + ''',2)'
				SELECT 	@stmnt_lastexec = "exec @err = sp_executesql 'USE " + @dbname + "..."
				exec @err = sp_executesql @sql
				IF (@err <> 0) GOTO Err_logspace_cur
		
				DECLARE @em_subj varchar(128)
				DECLARE @warn_level smallint 
						
				IF EXISTS (SELECT * FROM #DFSC_ShrinkLog_logspace 
									WHERE DBName = @dbname 
											AND LogSizeMB > @sh_th
											AND @sh_th <> 0
						) BEGIN 
							SET @em_subj = @log_file_name + ' of ' + @dbname + ' was shrinked, but its new size is still above ' 
							SET @warn_level = 3
				END	ELSE IF (@sh_th <> 0) BEGIN
							SET @em_subj = @log_file_name + ' of ' + @dbname + ' was shrinked, and its new size is below ' 
							SET @warn_level = 2
				END ELSE 	BEGIN 
							SET @em_subj = @log_file_name + ' of ' + @dbname + ' was truncated and shrinked' 
							SET @warn_level = 2
				END

				IF (@sh_th <> 0) BEGIN
					SET @em_subj = @em_subj + convert (varchar(100), @sh_th) + ' MB'
				END
	
				EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'DMDBA', 
										@AgentName = @proc_name,
										@Statement = @em_subj,
										@RecordCount = 0,
										@LogDesc = 	'Check other records for details',
										@UserId = NULL, 
										@IsLogOnly = 1
	
				SELECT 	@stmnt_lastexec = "EXEC aspr_DFSC_AddEmail 	@Subject = @em_subj,..."
				EXEC @err = aspr_DFSC_AddEmail 	@Subject = @em_subj,
									@WarnLevel = @warn_level, 
									@Body = 'Check INFO messages below for details'
				SELECT @rcnt = @@ROWCOUNT
				IF (@err <> 0) GOTO Err_sysfiles_cur
			END ELSE BEGIN	--		IF (@freespace_limit_diff < 0) BEGIN
				DECLARE @em_subj1 varchar(128)
				SET @em_subj1 = 'Log file of ' + @dbname + ' has overgrown threshold size but was not shrinked'
				DECLARE @em_details varchar(500)
				SET @em_details = 'Either Because there are still ' 
					+ isNull(convert(varchar(100), @freespace_limit_diff), 'NULL') 
					+ 'MB above drive free space limit or @LogNotifyOnly parameter was set to 1' + CHAR(10)
					+ 'Check INFO messages below for details'
	
				EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'DMDBA', 
										@AgentName = @proc_name,
										@Statement = @em_subj1,
										@RecordCount = 0,
										@LogDesc = 	'Check other records for details',
										@UserId = NULL, 
										@IsLogOnly = 1
	
				SELECT 	@stmnt_lastexec = "EXEC @err = aspr_DFSC_AddEmail 	@Subject = @em_subj1,..."
				EXEC @err = aspr_DFSC_AddEmail 	@Subject = @em_subj1,
									@WarnLevel = 2, 
									@Body = @em_details
				SELECT @rcnt = @@ROWCOUNT
				IF (@err <> 0) GOTO Err_sysfiles_cur
			END	--		IF (@freespace_limit_diff < 0) BEGIN
		END --DFSC_ShrinkLog_sysfiles_cur
		CLOSE DFSC_ShrinkLog_sysfiles_cur
		DEALLOCATE DFSC_ShrinkLog_sysfiles_cur
		DELETE #aspr_DFSC_ShrinkLog_sysfiles
	END --DFSC_ShrinkLog_logspace_cur
	CLOSE DFSC_ShrinkLog_logspace_cur
	DEALLOCATE DFSC_ShrinkLog_logspace_cur


	DELETE #DFSC_ShrinkLog_logspace
	SELECT 	@stmnt_lastexec = "	INSERT #DFSC_ShrinkLog_logspace (Dbname, LogSizeMB, LogUsedPercent, Status)"
	INSERT #DFSC_ShrinkLog_logspace (Dbname, LogSizeMB, LogUsedPercent, Status)
		EXEC ('DBCC SQLPERF(LOGSPACE)')
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	UPDATE ls SET ShrinkThreshold = isNull(st.ShrinkThreshold, @DefLogShrinkThresholdMB)
	FROM #DFSC_ShrinkLog_logspace ls LEFT JOIN #DFSC_ShrinkLog_shrink_thresh st
		ON st.DBName = ls.DBName

	SELECT 	@stmnt_lastexec = "EXEC @err = aspr_DFSC_LogSpaceInfo2Str @drives_space_info OUT"
	EXEC @err = aspr_DFSC_LogSpaceInfo2Str @log_space_info OUT
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err_sysfiles_cur
		
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'DMDBA', 
							@AgentName = @proc_name,
							@Statement = '/**** Shrinked Log Data ****/',
							@RecordCount = @rcnt,
							@LogDesc = 	@log_space_info,
							@UserId = NULL, 
							@IsLogOnly = 1

	SELECT 	@stmnt_lastexec = "EXEC aspr_DFSC_AddEmail 	@Subject = 'Shrinked Log Data', ..."
	EXEC @err = aspr_DFSC_AddEmail 	@Subject = 'Shrinked Log Data', 
					@WarnLevel = 1,
					@Body = @log_space_info
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err_sysfiles_cur

	RETURN 0
Err_sysfiles_cur:
		CLOSE DFSC_ShrinkLog_sysfiles_cur
		DEALLOCATE DFSC_ShrinkLog_sysfiles_cur
Err_logspace_cur:
	CLOSE DFSC_ShrinkLog_logspace_cur
	DEALLOCATE DFSC_ShrinkLog_logspace_cur
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
DECLARE @sql nvarchar(2000)
SELECT @sql = 'USE DFSC_Test' + CHAR(10)
				+ 'DBCC SHRINKFILE(''DFSC_Test_log'',2)'+ CHAR(10)
--				+ 'USE DFSC' 
EXEC (@sql)

DBCC SHRINKFILE('DFSC_Test_log',2)
*/