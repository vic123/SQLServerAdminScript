SET QUOTED_IDENTIFIER OFF
GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[BackupDBList]') 
		AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[BackupDBList]
GO
CREATE PROCEDURE BackupDBList @DBList nvarchar(2000), --i.e. 'DB1,DB2' - use
				/*declare @db_list nvarchar(2000)
					select @db_list = isnull(@db_list, '') + name + ', ' from master..sysdatabases order by name
					select @db_list
				*/ --for a list of all DBs
				@BackupDir 	nvarchar(500), --may contain or not ending '\'
				@BackupType 	varchar(5)= 'FULL', --|'LOG'|'DIFF'
				@EmailList	varchar(500) = NULL, --separated by ','
				@DBListDelimiter nvarchar(10) = ',',
				@Move2Zip bit = 1,
				@LogToSQLAdmin 	bit = 1

--				@DoSyncWithBackup bit = 0
--SET QUOTED_IDENTIFIER OFF
--DROP PROCEDURE [dbo].[BackupDBList]
/**********************************************************************************************
Procedure Name	: BackupDBList
Author		: Victor Blokhin (vic123.com)
Date		: Aug 2006
Purpose		: Full, log or differential backup of several databases with emailing of results. 
Referred	: StringListToTable function, ErrLog module
**********************************************************************************************/
/*MODIFICATIONS HISTORY IN CHRONOLOGICAL ORDER, WITH THE LATEST CHANGE BEING AT THE TOP.*/ 
/******************************************************************************************** 
MODIFIED BY      : 	Victor Blokhin 
MODIFICATIONS    :	In process of adding @DoSyncWithBackup parameter and related code for transactional repl.backups
DATE             :	Aug 2006

SELECT object_name(objid), o.xtype 
            FROM syspublications b, 
                 sysobjects o, 
                 sysextendedarticlesview a 
          LEFT JOIN sysobjects sync on a.sync_objid = sync.id 
          LEFT JOIN sysobjects fltr on a.filter = fltr.id 
           WHERE a.objid = o.id 
             AND a.pubid = b.pubid 


See Books Online, "Sysdatabases" for details, although it fails to mention 
that 16 = distribution database. 

 property of the 
SELECT DatabasePropertyex('SamplePublication', 'IsSyncWithBackup') 
SELECT DatabasePropertyex('?', '?')

SELECT * FROM master..sysservers

SELECT * FROM master..sysdatabases
sp_helpserver

SELECT * FROM msdb..sysjobs
SELECT * FROM msdb..sysjobsteps
SELECT * FROM msdb..sysjobhistory
*********************************************************************************************/
/******************************************************************************************** 
TEST
sp_configure 'show advanced options', 1;
RECONFIGURE;
sp_configure 'Ole Automation Procedures'
sp_configure 'Ole Automation Procedures', 1
RECONFIGURE;


EXEC BackupDBList @DBList = 'dfdf,SQAD', 
			@BackupDir = 'I:\SQLData\LAT1_Bak' , --may contain or not ending '\'
			@BackupType = 'FULL', --|'LOG'|'DIFF'
			@EmailList = 'victor@infoplanet-usa.com,vic@infoplanet-usa.com', --separated by ','
			@DBListDelimiter = ','--,

SELECT * FROM SQL_ERR_LOG

EXEC BackupDBList @DBList = 'SQLAdmin,master', 
			@BackupDir = 'I:\SQLData\LAT1_Bak' , --may contain or not ending '\'
			@BackupType = 'FULL', --|'LOG'|'DIFF'
			@EmailList = 'victor@infoplanet-usa.com,vic@infoplanet-usa.com', --separated by ','
			@DBListDelimiter = ','--,

EXEC BackupDBList @DBList = 'SQLAdmin', 
			@BackupDir = 'I:\SQLData\LAT1_Bak' , --may contain or not ending '\'
			@BackupType = 'LOG', --|'LOG'|'DIFF'
			@EmailList = 'victor@infoplanet-usa.com,vic@infoplanet-usa.com', --separated by ','
			@DBListDelimiter = ','--,

PRODUCTION:
EXEC BackupDBList @DBList = 'Billing,CDR', 
			@BackupDir = '\\Billing2\SQLBackup\Billing\' , --may contain or not ending '\'
			@BackupType = 'FULL', --|'LOG'|'DIFF'
			@EmailList = 'victor@infoplanet-usa.com',	
			@DBListDelimiter = ','--,

EXEC BackupDBList @DBList = 'Billing,CDR', 
			@BackupDir = '\\Billing2\SQLBackup\Billing\' , --may contain or not ending '\'
			@BackupType = 'LOG', --|'LOG'|'DIFF'
			@EmailList = 'victor@infoplanet-usa.com',	
			@DBListDelimiter = ','--,


***********************************/
AS BEGIN
	SET NOCOUNT ON
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
	if (@LogToSQLAdmin = 1) begin
		SELECT @proc_name = name,
				@db_name = db_Name()
			FROM sysobjects WHERE id = @@PROCID	
		SELECT @stmnt_lastexec =   'Input parameters'
		SELECT @log_desc = 	CHAR(10)
					+ '@DBList nvarchar(1000): ' + isNull('''' + @DBList + '''', 'NULL') + CHAR(10)
					+ '@BackupDir nvarchar(500): ' + isNull('''' + @BackupDir + '''', 'NULL') + CHAR(10)
					+ '@BackupType varchar(5): ' + isNull('''' + @BackupType + '''', 'NULL') + CHAR(10)
					+ '@EmailList varchar(500): ' + isNull('''' + @EmailList + '''', 'NULL') + CHAR(10)
					+ '@DBListDelimiter nvarchar(10): ' + isNull('''' + @DBListDelimiter + '''', 'NULL')
		EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
						@AgentName = @proc_name,
						@Statement = @stmnt_lastexec,
						@RecordCount = @rcnt,
						@LogDesc = @log_desc,
						@IsLogOnly = 1
		SET @log_desc = ''
	end

	--convert input DB list into table
	SELECT @stmnt_lastexec = "SELECT * INTO #DB2Backup FROM StringListToTable (@ValuePatternList, @ListDelimiter)"
	SELECT * INTO #DB2Backup FROM StringListToTable (@DBList, @DBListDelimiter)
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

--	IF (@DoSyncWithBackup = 1) BEGIN
--		DECLARE DistDBs_cur CURSOR FOR SELECT nstr FROM #DB2Backup
--	END

	--step over databases
	SELECT @stmnt_lastexec = "DECLARE BackupDBs_cur CURSOR FOR SELECT nstr FROM #DB2Backup..."
	DECLARE BackupDBs_cur CURSOR FOR SELECT nstr FROM #DB2Backup
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

	DECLARE @dbname sysname

	OPEN BackupDBs_cur
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

	WHILE (1=1) BEGIN
		SELECT @stmnt_lastexec = "FETCH NEXT FROM BackupDBs_cur INTO @dbname ..."
		FETCH NEXT FROM BackupDBs_cur INTO @dbname 
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err_BackupDBs_cur
		
		IF (@@FETCH_STATUS <> 0) BREAK

		DECLARE @device_name sysname, @backup_path nvarchar(500), @backup_fname nvarchar(255)
		SET @device_name = @dbname + 	'_' + convert(varchar(20),getdate(), 112) 
						+ '_' + replace(convert(varchar(20), getdate(), 108), ':', '')

		SET @device_name = @device_name + '_' + lower(@BackupType) 

		SET @backup_fname = @device_name + '.bak'

		IF (right(@BackupDir, 1) <> '\') SET @BackupDir = @BackupDir + '\'
		SET @backup_path = @BackupDir + @backup_fname

		-- Drop backup dump device if exists
		SELECT @stmnt_lastexec = "IF EXISTS (SELECT * FROM master..sysdevices WHERE NAME = @device_name) BEGIN ..."
		IF EXISTS (SELECT * FROM master..sysdevices WHERE NAME = @device_name) BEGIN
			if (@LogToSQLAdmin = 1 ) begin
				SET @log_desc = 'Dropping backup device ' + @device_name
				EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
								@AgentName = @proc_name,
								@Statement = @stmnt_lastexec,
								@RecordCount = @rcnt,
								@LogDesc = @log_desc,
								@IsWarnOnly = 1
				SET @log_desc = ''
			end

			SELECT 	@stmnt_lastexec = "EXEC @err = sp_dropdevice @device_name", 
				@err = NULL
			EXEC @err = sp_dropdevice @device_name
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err_BackupDBs_cur
		END --drop device

		-- Create backup dump device
--		SET @logmsg = 'Failed to create dump device : ' + @vbackupdevice 
		SELECT 	@stmnt_lastexec = "EXEC @err = master..sp_addumpdevice 'disk', @device_name, @backup_path", 
			@err = NULL,
			@log_desc = @device_name + '; ' + @backup_path
		EXEC @err = master..sp_addumpdevice 'disk', @device_name, @backup_path
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
		SET @log_desc = ''

		DECLARE @start_dt datetime, @stop_dt datetime
		SET @start_dt = getdate()
		SET @log_desc = 'Invalid @BackupType parameter'
		SET @log_desc = ''

		SELECT 	@stmnt_lastexec = "BACKUP DATABASE @dbname TO @device_name .....", 
			@log_desc = @dbname + '; ' + @device_name
		IF (upper(@BackupType) = 'FULL') BEGIN
			BACKUP DATABASE @dbname TO @device_name 
				WITH  INIT, NAME = @dbname, NOSKIP , STATS = 100, DESCRIPTION = @backup_path, NOFORMAT 
		END ELSE IF (upper(@BackupType) = 'LOG') BEGIN
			BACKUP LOG @dbname TO @device_name 	
				WITH  INIT, NAME = @dbname, NOSKIP , STATS = 100, DESCRIPTION = @backup_path, NOFORMAT 
		END ELSE IF (upper(@BackupType) = 'DIFF') BEGIN
			BACKUP DATABASE @dbname TO @device_name 
				WITH  INIT, DIFFERENTIAL, NAME = @dbname, NOSKIP , STATS = 100, DESCRIPTION = @backup_path, NOFORMAT 
		END ELSE GOTO Err_BackupDBs_cur
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		/*
			INIT - BOL: If INIT is specified, any existing backup set on that device is overwritten.
				Procedure creates only single backup per device (i.e. - file).
			NOSKIP - BOL: Instructs the BACKUP statement to check the expiration date of all backup sets on the media before allowing them to be overwritten. 
				Prevents from overwriting of contents of already existing backup device (i.e. file)
				?? may be dropping of device code (above) should be removed or made optional
			STATS - BOL: Displays a message each time another percentage completes
				Minimize unnecessary output. It is better to be minimized to error messages only if any, however it is there is no option to supress that output for the BACKUP statement completely.
			NOFORMAT - BOL: Specifies that the media header should not be written on all volumes used for this backup operation. This is the default behavior.
		*/

		SET @stop_dt = getdate()
		IF (@err <> 0) BEGIN 
			SET @log_desc = 'FAILED database ' + @dbname + ' ' + lower(@BackupType) 
				+ ' backup in ' + convert(varchar, DATEDIFF (ss, @start_dt, @stop_dt)) + ' secs to ' + @backup_path + '; ' 
				+ @log_desc
			if (@LogToSQLAdmin = 1 ) begin
				EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
								@AgentName = @proc_name,
								@Statement = @stmnt_lastexec,
								@RecordCount = @rcnt,
								@LogDesc = @log_desc,
								@IsWarnOnly = 1
			end else raiserror (@log_desc, 16, 1)
			SET @log_desc = ''
		END ELSE BEGIN
			if (@LogToSQLAdmin = 1 ) begin
				SET @log_desc = 'Database ' + @dbname + ' ' + lower(@BackupType) + ' backup completed in ' + convert(varchar, DATEDIFF (ss, @start_dt, @stop_dt)) + ' secs to ' + @backup_path
				EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
								@AgentName = @proc_name,
								@Statement = @stmnt_lastexec,
								@RecordCount = @rcnt,
								@LogDesc = @log_desc,
								@IsLogOnly = 1
				SET @log_desc = ''
			end
		END

		IF (@Move2Zip = 1) BEGIN
			SELECT 	@stmnt_lastexec = "EXEC @err = ProcessFiles_Zip_7Zip @Dir = @BackupDir, @FileName = @backup_fname, @TargetDir$ZipFilePrefix = @BackupDir, @Move = 1", @err = NULL
			EXEC @err = ProcessFiles_Zip_7Zip @Dir = @BackupDir, @FileName = @backup_fname, @TargetDir$ZipFilePrefix = @BackupDir, @Move = 1 
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err_BackupDBs_cur
		END

	END --WHILE
	CLOSE BackupDBs_cur
	DEALLOCATE BackupDBs_cur

	SET @err_fin = 0
	GOTO Email
Err_BackupDBs_cur:
	CLOSE BackupDBs_cur
	DEALLOCATE BackupDBs_cur

Err:
	if (@LogToSQLAdmin = 1 ) begin
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
	if (@EmailList is Not NULL ) begin
		EXEC @err = ADM_MAIL_CURSPROC_SQL_ERR_LOG @SystemName = @db_name,
							@AgentName = @proc_name,
							@StatementBeg = 'Input parameters',
							@EmailList = @EmailList,
							@WarnLevel = 0
	end
--select @err 
		IF (@err <> 0) GOTO Err_Final
	RETURN @err_fin

Err_Final:
	if (@LogToSQLAdmin = 1 ) begin
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



--sp_helptext BackupDBList


