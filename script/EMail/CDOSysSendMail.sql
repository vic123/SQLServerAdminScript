
SET QUOTED_IDENTIFIER OFF
GO
IF OBJECT_ID('CDOSysSendMail') IS NOT NULL  
  DROP PROCEDURE CDOSysSendMail
go

CREATE PROCEDURE CDOSysSendMail --SET QUOTED_IDENTIFIER OFF 
				@From varchar(8000), 
				@To varchar(8000),
				@Subject varchar(8000),
--(070417)				@Message varchar(8000),
				@Message text,
				--Valid hostname or IP address pointing an SMTP mail server
				@Server varchar(500),  --worked with it from here too, but
--				@Server varchar(500) = 'smtp.gmail.com' --worked with it from here too, but
					--only to email addresses that are under local ISP control,
					--for others getting Server response: 553 sorry, that domain isn't in my list of allowed rcpthosts (#5.7.1)
				--'smtp.gmail.com'  --Server response: 530 5.7.0 Must issue a STARTTLS command first q19sm2934692qbq
				@Pwd varchar(100)
/*
--Tests:





*/

AS BEGIN
--declare a set of standard error logging variables
	DECLARE @proc_name sysname				--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	DECLARE @db_name sysname				-- ----""------
	SELECT 	@proc_name = name, @db_name = db_Name() FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int				--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @log_desc nvarchar(4000)			-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)	-- ----""------

	DECLARE @hr_obj int							-- var for OAGetErrorInfo
	DECLARE @hr int								-- HRESULT



	--log input parameters, it is a valuable info
	SELECT @proc_name = name, @db_name = db_Name() FROM sysobjects WHERE id = @@PROCID	
	SELECT @stmnt_lastexec =   'Input parameters'
	SELECT @log_desc = 	'@From varchar(8000): ' + isNull('''' + @From + '''', 'NULL') + CHAR(10)
				+ '@To varchar(8000): ' + isNull('''' + @To + '''', 'NULL') + CHAR(10)
				+ '@Subject varchar(8000): ' + isNull('''' + @Subject + '''', 'NULL') + CHAR(10)
--(070417)				+ '@Message varchar(8000): ' + isNull('''' + @Message + '''', 'NULL') + CHAR(10)
	SELECT @log_desc = @log_desc + '@Message text: ' + isNull('''' + substring (@Message, 1, 50) + '...'
					+ substring (@Message, Datalength(@Message)- 50, 50) + ''''
				,'NULL') + CHAR(10)

	SELECT @log_desc = @log_desc + '@Server varchar(500): ' + isNull('''' + @Server + '''', 'NULL') + CHAR(10)
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
					@AgentName = @proc_name,
					@Statement = @stmnt_lastexec,
					@RecordCount = @rcnt,
					@LogDesc = 	@log_desc,
					@IsLogOnly = 1
	SET @log_desc = ''

--@hr_obj = @fso,	--copy objecttoken to be used into @hr_obj
	SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OACreate 'CDO.Message', @hr_obj OUT "
	EXEC @hr = sp_OACreate 'CDO.Message', @hr_obj OUT 
	IF (@hr <> 0) GOTO OAErr

--***************Configuring the Message Object ******************
--http://msdn.microsoft.com/library/default.asp?url=/library/en-us/cdosys/html/37be0471-06bd-489d-8bf2-5c22bb7ce17c.asp
	-- cdoSendUsingPickup  1 Send message using the local SMTP service pickup directory.
	-- cdoSendUsingPort  2 Send the message using the network (SMTP over the network). 
	SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OASetProperty @iMsg, ...."	
	EXEC @hr = sp_OASetProperty @hr_obj, 
		'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/sendusing").Value','2'
	-- This is to configure the Server Name or IP address. Replace MailServerName by the name or IP of your SMTP Server.
	EXEC @hr = sp_OASetProperty @hr_obj, 
		'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/smtpserver").Value', 
		@Server
	IF (@hr <> 0) GOTO OAErr


	EXEC @hr = sp_OASetProperty @hr_obj, 
		'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/sendusername").Value', 
		@From

	EXEC @hr = sp_OASetProperty @hr_obj, 
		'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/sendpassword").Value', 
		@Pwd
	IF (@hr <> 0) GOTO OAErr

	EXEC @hr = sp_OASetProperty @hr_obj, 
		'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/smtpaccountname").Value', 
		@From
	IF (@hr <> 0) GOTO OAErr


--cdoAnonymous  0 Do not authenticate.
--cdoBasic  1 Use basic (clear-text) authentication. The configuration sendusername/sendpassword or postusername/postpassword fields are used to specify credentials.
--cdoNTLM  2 Use NTLM authentication (Secure Password Authentication in Microsoft Outlook Express). The current process security context is used to authenticate with the service.
	EXEC @hr = sp_OASetProperty @hr_obj, 
		'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/smtpauthenticate").Value', 
		'1'
	IF (@hr <> 0) GOTO OAErr

 

	-- Save the configurations to the message object.
	EXEC @hr = sp_OAMethod @hr_obj, 'Configuration.Fields.Update', null
	IF (@hr <> 0) GOTO OAErr
	-- Set the e-mail parameters.
	EXEC @hr = sp_OASetProperty @hr_obj, 'To', @To
	IF (@hr <> 0) GOTO OAErr
	EXEC @hr = sp_OASetProperty @hr_obj, 'From', @From
	IF (@hr <> 0) GOTO OAErr
	EXEC @hr = sp_OASetProperty @hr_obj, 'Subject', @Subject
	IF (@hr <> 0) GOTO OAErr

-- If you are using HTML e-mail, use 'HTMLBody' instead of 'TextBody'.
	EXEC @hr = sp_OASetProperty @hr_obj, 'TextBody', @Message
	IF (@hr <> 0) GOTO OAErr
--	EXEC @hr = sp_OASetProperty @hr_obj, 'HTMLBody', @Message
--	IF (@hr <> 0) GOTO OAErr

	SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OAMethod @hr_obj, 'Send', NULL...."	
	EXEC @hr = sp_OAMethod @hr_obj, 'Send', NULL
--071011	IF (@hr <> 0) GOTO OAErr
	IF (@hr <> 0) BEGIN
		SET @log_desc  = isNull(@log_desc, '') + dbo.OAGetErrorInfo (@hr_obj, @hr) 
		SET @err = isNull(@hr, -4711)
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

	RETURN @hr
OAErr:
	SET @log_desc  = isNull(@log_desc, '') + dbo.OAGetErrorInfo (@hr_obj, @hr) 
--	SELECT @log_desc 
	SET @err = isNull(@hr, -4711)
--error handler
Err:
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
								@AgentName = @proc_name,
								@Statement = @stmnt_lastexec, 
								@ErrCode = @err, 
								@RecordCount = @rcnt, 
								@LogDesc = @log_desc,
								@EMNotify = NULL, 
								@UserId = NULL
--failure end
	RETURN @err
END
