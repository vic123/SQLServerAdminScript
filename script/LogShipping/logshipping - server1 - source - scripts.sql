--USE LogShipping
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[DBBackup_sp]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[DBBackup_sp]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SendMail_sp]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SendMail_sp]
GO

CREATE PROCEDURE SendMail_sp (@PFROM NVARCHAR(255), @PTO NVARCHAR(255), 
								@PSUBJECT NVARCHAR(255), @PBODY NVARCHAR(4000), 
								@pattachmentfilename nvarchar(1000) = null) AS
	
	DECLARE @msg nvarchar (4000)
	SET @msg = @PSUBJECT + CHAR(10) + @PBODY
	EXEC sp_EmailAlert2 @ModuleName = 'LogShipping', @Msg = @msg, @CcList =  @PTO

/*
declare @object int,
 @hr int,
 @rc int,
 @output varchar(400),
 @description varchar (400),
 @source varchar(400),
 @v_returnval varchar(1000),
 @serveraddress varchar(1000)

	set @serveraddress = '163.232.6.188'

	exec @hr = sp_OACreate 'SimpleCDO.Message', @object OUT

	if @pattachmentfilename is null or @pattachmentfilename = ''
		exec @hr = sp_OAMethod @object, 'SendMessage', @v_returnval OUT, @PTO, @PFROM, @PSUBJECT, @PBODY, @serveraddress, @v_returnval
	else
		exec @hr = sp_OAMethod @object, 'SendMessageWithAttachment', @v_returnval OUT, @PTO, @PFROM, @PSUBJECT, @PBODY, @serveraddress, @pattachmentfilename, @v_returnval
	
	exec @hr = sp_OADestroy @object
*/

/*
-- THIS PROGRAM REQUIRES JMAIL.DLL TO BE REGISTERED ON THE SERVER (16/11/2000 3:34PM)

DECLARE  @sender varchar(100)
DECLARE  @sendername varchar(100)
DECLARE  @serveraddress varchar(255)
DECLARE  @recipient varchar(255)
DECLARE  @recipientBCC varchar(200)
DECLARE  @recipientCC varchar(200)
DECLARE  @attachment varchar(100)
DECLARE  @subject varchar(255)
DECLARE  @mailbody varchar(8000)

set @recipientBCC = ''
set @recipientCC =''
set @attachment =''
set @serveraddress = '163.232.6.188'
set  @sendername = ''
set @sender = @PFROM
set @recipient = @PTO
set @subject = @PSUBJECT
set @mailbody = @PBODY



--Stored procedure using Dimac w3 JMail by Mats Cederholm, mats@globalcom.se, Global Communications WWW AB
--Sending email by instantiating w3 JMail instead of SQL mail.



--Declares variables for input/output from w3 JMail and errormessage

declare @object int,
 @hr int,
 @rc int,
 @output varchar(400),
 @description varchar (400),
 @source varchar(400)


--Set all values to w3 JMail needed to send the email


exec @hr = sp_OACreate 'jmail.smtpmail', @object OUT

--print '@@@@@@@@@@'
--print @hr
--print '@@@@@@@@@@'

exec @hr = sp_OASetProperty @object, 'Sender', @sender
exec @hr = sp_OASetProperty @object, 'ServerAddress', @serveraddress
exec @hr = sp_OAMethod @object, 'AddRecipient', NULL , @recipient
exec @hr = sp_OASetProperty @object, 'Subject', @subject
exec @hr = sp_OASetProperty @object, 'Body', @mailbody

--print @serveraddress


--Set some more values, depending on the value of the variables 


if not(@attachment='')
 exec @hr = sp_OAMethod @object, 'Addattachment', NULL , @attachment
 print @attachment
if not(@recipientBCC='')
 exec @hr = sp_OAMethod @object, 'AddRecipientBCC', NULL , @recipientBCC
if not(@recipientCC='')
 exec @hr = sp_OAMethod @object, 'AddRecipientCC', NULL , @recipientCC
if not(@sendername='')
 exec @hr = sp_OASetProperty @object, 'SenderName', @sendername


--Call execute to send the email 

exec @hr = sp_OAMethod @object, 'execute', NULL


--Catch possible errors 


if @hr <> 0
begin
--	print 'failed email'
--	print @hr	

	exec @hr = sp_OAGetErrorInfo @object, @source OUT, @description OUT	

	print @source
	print @description
end



--Kill the object 

exec @hr = sp_OADestroy @object

*/
return 0
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


CREATE PROCEDURE dbo.DBBackup_sp @p_type  as varchar(80) = 'full', @p_database as varchar(200), 
--060323				@p_cleanuppath as varchar(100) = null, 
--060323				@p_retaindays as integer = 5, 
				@p_retaindays as integer = NULL, 
--060323				@p_zippath as varchar(100) = null, 
				@p_zipexecprefix as varchar(100) = null, 
				@p_zipit as integer = 0, 
				@p_dest1 as varchar(1000) = 'c:\', 
				@p_dest2 as varchar(1000) = null, 
				@p_emailaddress as varchar(100), 
				@p_emailme as varchar(1) = 'N' as 
SET NOCOUNT ON
--
-- Usage Example :  exec DBBackup_sp 'full', 'northwind', 'd:\backups', 1, 'd:\backups', 1, 'd:\backups\','d:\backups\duplex\', 'ckempste@iinet.net.au', 'N'
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

--060323				if @p_zipit = 1 and @v_error <= 0 and @p_zippath is not null
				if @p_zipit = 1 and @v_error <= 0 and @p_zipexecprefix is not null

				begin
					-- Gzip the file
		
--060323					SELECT @cmdline = @p_zippath + '\gzip.exe ' + @v_filename 
					SELECT @cmdline = @p_zipexecprefix + ' ' + @v_filename + ' ' + @v_filename + '.zip'
					EXEC @v_error = master..xp_cmdshell @cmdline, NO_OUTPUT
					if @v_error > 0
--060323						set @v_errortext = 'Database ' + @p_database + '  failed to ZIP backup to dump destionation' + @p_dest2 + ' from source ' + @p_dest2 + ' using zip command ' + @p_zippath + '\gzip.exe'
						set @v_errortext = 'Database ' + @p_database + '  failed to ZIP backup to dump destionation' + @p_dest2 + ' from source ' + @p_dest2 + ' using zip command ' + @p_zipexecprefix + ' ' + @v_filename 
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

						EXEC @v_error = master..xp_cmdshell @cmdline, NO_OUTPUT
			
						if @v_error > 0
							set @v_errortext ='Database ' + @p_database + '  failed to duplex backup to dump destionation ' + @p_dest2 + ' from source ' + @v_filename
					END
				END

				-- Cleanup any existing files as required

--060323				if @v_error <= 0 and @p_cleanuppath is not null 	
				if @v_error <= 0 and @p_retaindays is not null 	
				begin
					-- if zip mode enabled, then delete based on gz extension
--060323					SELECT @cmdline = @p_cleanuppath + '\dtdelete.exe ' + @p_dest1 + '*.gz' + ' ' + cast(@p_retaindays as varchar)
--060323					EXEC @v_error = master..xp_cmdshell @cmdline, NO_OUTPUT
					SELECT @cmdline = @p_dest1 + '*.zip'
					EXEC @v_error = aspr_DFSC_DelOldFiles @cmdline,  @p_retaindays

					if @v_error > 0
						set @v_errortext ='Database ' + @p_database + '  failed to delete old files using command ' + @cmdline
					else begin
--060323						SELECT @cmdline = @p_cleanuppath + '\dtdelete.exe ' + @p_dest1 + '*.bak' + ' ' +cast(@p_retaindays as varchar)
--060323						EXEC @v_error = master..xp_cmdshell @cmdline, NO_OUTPUT
						SELECT @cmdline = @p_dest1 + '*.bak'
						EXEC @v_error = aspr_DFSC_DelOldFiles @cmdline,  @p_retaindays
						if @v_error > 0
							set @v_errortext ='Database ' + @p_database + '  failed to delete old files using command ' + @cmdline
					end

					-- run against duplexed directory as well 

					if @p_dest2 is not null and @v_error <= 0 begin

						-- if zip mode enabled, then delete based on gz extension
--060323						SELECT @cmdline = @p_cleanuppath + '\dtdelete.exe ' + @p_dest2 + '*.gz' + ' ' +cast(@p_retaindays as varchar)
--060323						EXEC @v_error = master..xp_cmdshell @cmdline, NO_OUTPUT
						SELECT @cmdline = @p_dest2 + '*.zip'
						EXEC @v_error = aspr_DFSC_DelOldFiles @cmdline,  @p_retaindays
						if @v_error > 0
							set @v_errortext ='Database ' + @p_database + '  failed to delete old duplexed files using command ' + @cmdline
						else begin
--060323							SELECT @cmdline = @p_cleanuppath + '\dtdelete.exe ' + @p_dest2 + '*.bak' + ' ' +cast(@p_retaindays as varchar)
--060323							EXEC @v_error = master..xp_cmdshell @cmdline, NO_OUTPUT
							SELECT @cmdline = @p_dest2 + '*.bak'
							EXEC @v_error = aspr_DFSC_DelOldFiles @cmdline,  @p_retaindays
							if @v_error > 0
								set @v_errortext ='Database ' + @p_database + '  failed to delete old duplexed files using command ' + @cmdline
						end
					end
				end  
			END
		END
	END

	set @from = @@SERVERNAME
	
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


