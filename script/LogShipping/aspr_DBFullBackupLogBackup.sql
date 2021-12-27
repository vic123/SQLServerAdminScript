
/*
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SendMail_sp]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SendMail_sp]
*/
GO
/*
CREATE PROCEDURE SendMail_sp (@PFROM NVARCHAR(255), @PTO NVARCHAR(255), 
								@PSUBJECT NVARCHAR(255), @PBODY NVARCHAR(4000), 
								@pattachmentfilename nvarchar(1000) = null) AS
BEGIN 
	SELECT @PFROM, @PTO, @PSUBJECT, @PBODY, @pattachmentfilename
END
*/
go

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[aspr_DBFullBackupLogBackup_AppendErrorText]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[aspr_DBFullBackupLogBackup_AppendErrorText]
GO


CREATE PROCEDURE aspr_DBFullBackupLogBackup_AppendErrorText @ErrPath varchar(500), @ErrNum int, @ErrorText varchar(4000) OUTPUT AS
BEGIN
--	WAITfor delay '00:00:05'
	DECLARE @cmdline varchar(250)
	SELECT @ErrorText = isNull(@ErrorText, '') + CHAR(10) 
						+ 'Error Number: ' + isNull(convert(varchar(100), @ErrNum), 'NULL') + CHAR(10) 
						+ 'Std Output: ' 

	SELECT @ErrorText = isNull(@ErrorText, '') + CHAR(10) + isNull(txt, 'NULL') 
		FROM #output ORDER BY id 

	DELETE #output

	SELECT @cmdline = 'type ' + @ErrPath

	INSERT INTO #output(txt)
		EXEC xp_cmdshell @cmdline 

	SELECT @ErrorText = isNull(@ErrorText, '') + CHAR(10) + 'Std Error:' 
	SELECT @ErrorText = isNull(@ErrorText, '') + CHAR(10) + isNull(txt, 'NULL') 
		FROM #output ORDER BY id 

END 
GO


if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[aspr_DBFullBackupLogBackup]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[aspr_DBFullBackupLogBackup]
GO


CREATE PROCEDURE dbo.aspr_DBFullBackupLogBackup @p_type  as varchar(80) = 'full', @p_database as varchar(200),
				@p_cleanuppath as varchar(100) = null, @p_retaindays as integer = 5,
				@p_zippath as varchar(100) = null, @p_zipit as integer = 0,
				@p_dest1 as varchar(1000) = 'c:\', @p_dest2 as varchar(1000) = null,
				@p_emailaddress as varchar(100), @p_emailme as varchar(1) = 'N' as
SET NOCOUNT ON
--
-- Usage Example :  exec aspr_DBFullBackupLogBackup 'full', 'northwind', 'd:\backups', 1, 'd:\backups', 1, 'd:\backups\','d:\backups\duplex\', 'ckempste@iinet.net.au', 'N'
--
-- NOTE:  if using the root directory, ensure no \ is used, ie, c:\ will be invalid
--	   also assumes use of the gzip and dtdelete.exe programs
--
-- Filename will be :  \<db-name>_YYYMMDD_HHMISS_<full or diff or trn>.bak with a .gz if compression was requested
--
-- Assumes the following:
-- a)  SendMail_sp  stored procedure also exists
-- b)  Tested on SS2k only
-- c)  Will do a FULL backup of master database even if other types are specified
-- d)  if using the root directory, ensure no \ is used, ie, c:\ will be invalid
-- e) assumes use of the gzip and dtdelete.exe programs
--
-- To do:
--
-- a)  Check database recovery mode status to determine if TRN log backups are valid
-- b)  Check error codes after backup command was run
-- c)  How to verify the backup file ok? (trap backup info sent to standard out and send via email to administrator)
-- d)  Verify paths (destinations) and space on disk
-- e)  vxtmpdump  dump device check if already exists or error on removal/addition
-- f)  Add email dest to backup parameters


DECLARE @v_starttime DATETIME
DECLARE @v_endtime DATETIME
DECLARE @v_filename VARCHAR(400)
DECLARE @v_count INTEGER
DECLARE @v_error INTEGER
DECLARE @v_status INTEGER
DECLARE @v_errortext VARCHAR(4000)
DECLARE @cmdline VARCHAR(250)
DECLARE @from VARCHAR(80)
DECLARE @vbackupdevice VARCHAR(80)
DECLARE @v_subject varchar(120)

BEGIN
	-- Check database status before attempting backup

--060419-output
	DECLARE 	@err_path varchar(250)
	
		CREATE TABLE #output(
			id int IDENTITY, 
			txt varchar(4000),
			err varchar(4000)
		)
	SELECT @err_path = @p_dest1 + 'err'

	set @v_status = (select count(*) from master.dbo.sysdatabases where lower(name ) = @p_database)

	if @v_status <= 0
		set @v_errortext = 'Database ' + @p_database + ' does not exist in sysdatabases table. Backup failed.'
	else begin
		set @v_status = (select count(*) from master.dbo.sysdatabases where lower(name ) = @p_database and status in (32,64, 128, 512, 1024, 4096, 32768, 1073741824))

		if @v_status > 0
			set @v_errortext = 'Database ' + @p_database + ' has a status that has forced the backup not to run, status may be one of the following 32, 64, 128, 512, 1024, 4096, 32768, 1073741824.'
	else begin
		-- Check recovery model of database vs requested backup type

		-- if (lower(@p_type) = 'log') and (select count(*) from master.dbo.sysdatabases where lower(name ) = @p_database and status  = 8) > 0
		-- set @v_errortext = 'Database ' + @p_database+ ' has a SIMPLE recovery mode and you can NOT do transaction log backups on this database.'
		-- else begin

		-- Create the dump filename

		set @v_filename = convert(varchar(20),getdate(), 112) + '_' + convert(varchar(20), getdate(), 108)

		if lower(@p_type) = 'full'
			set @v_filename = @p_database + '_' + @v_filename + '_full.bak'
		if lower(@p_type) = 'log'
			  set @v_filename = @p_database + '_' + @v_filename + '_trn.bak'
		if lower(@p_type) = 'diff'
			  set @v_filename = @p_database + '_' + @v_filename + '_diff.bak'

		set @v_filename = replace(@v_filename, ':','')
		set @v_filename = @p_dest1 + @v_filename

		-- Create the backup dump device

		set @vbackupdevice = @p_database + '_' + convert(varchar, getdate(), 104) + '_' + convert(varchar, getdate(), 108)

		if exists (select 'x' from master..sysdevices where name = @vbackupdevice)
			exec sp_dropdevice @vbackupdevice

		EXEC @v_error = master..sp_addumpdevice 'disk', @vbackupdevice, @v_filename

		if @v_error > 0
			set @v_errortext = 'Failed to create dump device : ' + @vbackupdevice
		else
		begin
			set @v_starttime = getdate()

			if lower(@p_type) = 'full' or lower(@p_database) = 'master'
				BACKUP DATABASE @p_database TO @vbackupdevice WITH  INIT,  NAME = @p_database, NOSKIP , STATS = 10, DESCRIPTION = @v_filename, NOFORMAT

			if lower(@p_type) = 'log' and lower(@p_database) <> 'master'
				BACKUP LOG @p_database TO @vbackupdevice WITH  INIT, NAME = @p_database, NOSKIP , STATS = 10, DESCRIPTION =@v_filename, NOFORMAT

			if lower(@p_type) = 'diff' and lower(@p_database) <> 'master'
				BACKUP DATABASE @p_database TO @vbackupdevice WITH  INIT, DIFFERENTIAL, NAME = @p_database, NOSKIP , STATS = 10, DESCRIPTION = @v_filename, NOFORMAT

			set @v_error = @@ERROR
			set @v_endtime = getdate()

			IF @v_error > 0
				set @v_errortext = 'Database ' + @p_database + '  failed to run backup of type ' + @p_type + ' to dump destionation ' + @v_filename
			ELSE
			BEGIN
				  -- Remove the backup device now the job is done

				if exists (select 'x' from master..sysdevices where name = @vbackupdevice)
					EXEC @v_error = master..sp_dropdevice @vbackupdevice

				if @v_error > 0
					set @v_errortext = 'Failed to drop dump device : ' + @vbackupdevice

				-- zip the file if requested to do so...

				if @p_zipit = 1 and @v_error <= 0 and @p_zippath is not null
				begin
					-- Gzip the file

					SELECT @cmdline = @p_zippath + '\gzip.exe ' + @v_filename
					SELECT @cmdline = @cmdline + ' 2>' + @err_path	--060419-output

					DELETE #output				--060419-output
					INSERT INTO #output(txt) 	--060419-output
						EXEC @v_error = master..xp_cmdshell @cmdline--060419-output, NO_OUTPUT

					if @v_error > 0 BEGIN
						set @v_errortext = 'Database ' + @p_database + '  failed to ZIP backup to dump destionation' + @p_dest2 + ' from source ' + @p_dest2 + ' using zip command ' + @p_zippath + '\gzip.exe'
						EXEC aspr_DBFullBackupLogBackup_AppendErrorText @err_path, @v_error, @v_errortext OUTPUT	--060419-output
					END
				END

					-- after zip, duplex the backup

					if @p_dest2 is not null and @v_error <= 0
					BEGIN
						-- Copy file
						if @p_zipit = 0
							SELECT @cmdline ='COPY "' + @v_filename + '" "' + @p_dest2 + '"'
						else
							SELECT @cmdline ='COPY "' + @v_filename + '.gz" "' + @p_dest2 + '"'
						print @cmdline
						DELETE #output		--060419-output
						INSERT INTO #output(txt) --060419-output
							EXEC @v_error = master..xp_cmdshell @cmdline--060419-output, NO_OUTPUT

						if @v_error > 0 BEGIN
							set @v_errortext ='Database ' + @p_database + '  failed to duplex backup to dump destionation ' + @p_dest2 + ' from source ' + @v_filename
							EXEC aspr_DBFullBackupLogBackup_AppendErrorText @err_path, @v_error, @v_errortext OUTPUT	--060419-output
						END
					END
				END

				-- Cleanup any existing files as required

				if @v_error <= 0 and @p_cleanuppath is not null
				begin
					-- if zip mode enabled, then delete based on gz extension
					SELECT @cmdline = @p_cleanuppath + '\dtdelete.exe ' + @p_dest1 + '*.gz' + ' ' + cast(@p_retaindays as varchar)
					DELETE #output		--060419-output
					INSERT INTO #output(txt) --060419-output
						EXEC @v_error = master..xp_cmdshell @cmdline--060419-output, NO_OUTPUT

					if @v_error > 0 BEGIN
						set @v_errortext ='Database ' + @p_database + '  failed to delete old files using command ' + @cmdline
						EXEC aspr_DBFullBackupLogBackup_AppendErrorText @err_path, @v_error, @v_errortext OUTPUT	--060419-output
					END
					else begin

						SELECT @cmdline = @p_cleanuppath + '\dtdelete.exe ' + @p_dest1 + '*.bak' + ' ' +cast(@p_retaindays as varchar)
						DELETE #output		--060419-output
						INSERT INTO #output(txt) --060419-output
							EXEC @v_error = master..xp_cmdshell @cmdline--060419-output, NO_OUTPUT

						if @v_error > 0 BEGIN
							set @v_errortext ='Database ' + @p_database + '  failed to delete old files using command ' + @cmdline
							EXEC aspr_DBFullBackupLogBackup_AppendErrorText @err_path, @v_error, @v_errortext OUTPUT	--060419-output
						END
					end

					-- run against duplexed directory as well

					if @p_dest2 is not null and @v_error <= 0 begin

						-- if zip mode enabled, then delete based on gz extension
						SELECT @cmdline = @p_cleanuppath + '\dtdelete.exe ' + @p_dest2 + '*.gz' + ' ' +cast(@p_retaindays as varchar)
						DELETE #output		--060419-output
						INSERT INTO #output(txt) --060419-output
							EXEC @v_error = master..xp_cmdshell @cmdline--060419-output, NO_OUTPUT

						if @v_error > 0 BEGIN
							set @v_errortext ='Database ' + @p_database + '  failed to delete old duplexed files using command ' + @cmdline
							EXEC aspr_DBFullBackupLogBackup_AppendErrorText @err_path, @v_error, @v_errortext OUTPUT	--060419-output
						END
						else begin
							SELECT @cmdline = @p_cleanuppath + '\dtdelete.exe ' + @p_dest2 + '*.bak' + ' ' +cast(@p_retaindays as varchar)
							DELETE #output		--060419-output
							INSERT INTO #output(txt) --060419-output
								EXEC @v_error = master..xp_cmdshell @cmdline--060419-output, NO_OUTPUT

							if @v_error > 0 BEGIN
								set @v_errortext ='Database ' + @p_database + '  failed to delete old duplexed files using command ' + @cmdline
								EXEC aspr_DBFullBackupLogBackup_AppendErrorText @err_path, @v_error, @v_errortext OUTPUT	--060419-output
							END
						end
					end
				end
			END
		END
	END

	set @from = @@SERVERNAME
	Print Isnull(@v_errortext, 'it is NULL')
	if @v_errortext is not null begin
		set @v_subject = 'FAILED Database Backup of ' + @p_database + ' - ' + @from
		exec SendMail_sp @p_emailaddress, @p_emailaddress, @v_subject, @v_errortext
	end

	if @p_emailme = 'Y' and @v_errortext is  null begin
		set @v_errortext = 'Successful ' + @p_type + ' backup of ' + @p_database + ', start time ' + cast(@v_starttime as varchar) + ' to ' + cast(@v_endtime as varchar) + ' (does not include zip and duplex time)'
		set @v_subject = 'Successful Database Backup of ' + @p_database + ' - ' + @from
		exec SendMail_sp @p_emailaddress,@p_emailaddress, @v_subject, @v_errortext
	end
END



GO
