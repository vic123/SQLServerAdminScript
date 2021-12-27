SET QUOTED_IDENTIFIER OFF
IF OBJECT_ID('SMTPSendMail') IS NOT NULL  
  DROP PROCEDURE SMTPSendMail
go

CREATE PROCEDURE SMTPSendMail 	--SET QUOTED_IDENTIFIER OFF 
				@From varchar(8000), 
				@To varchar(8000),
				@Subject varchar(8000),
				@Message varchar(8000),
				--Valid hostname or IP address pointing an SMTP mail server
				@Server varchar(500) = 'mail.infoplanet-usa.com' --worked with it from here too, but
--				@Server varchar(500) = 'smtp.gmail.com' --worked with it from here too, but
					--only to email addresses that are under local ISP control,
					--for others getting Server response: 553 sorry, that domain isn't in my list of allowed rcpthosts (#5.7.1)
				--'smtp.gmail.com'  --Server response: 530 5.7.0 Must issue a STARTTLS command first q19sm2934692qbq



/*

--SMTP error capturing:
To capture error output - not possible for now
However, the documentation for xp_smtp_sendmail does not state anything 
about returned error number, so that isn't anything we should rely on 
anyhow. Considering giving feedback on www.SQLDev.Net for such a request. 
Checking panned functionality enhancements on the web-site, you will find 
that returning error text as an out parameter is already a planned feature. 


The error text is returned in the same way as a PRINT, i.e., as text in 
contrast to a result set. Technically, this is a bit different from an error 
message, which carries a severity level and state. Note that QA does not 
show the red text containing error number etc for severity level under 11. 
Run below in QA and you will see that all three messages are returned the 
same way, as text only: 


DECLARE @rc int 
EXEC @rc = master.dbo.xp_smtp_sendmail 
    @FROM   = N'MyEm...@MyDomain.com', 
    @TO     = N'MyFri...@HisDomain.com' 
SELECT @rc, @@ERROR 

PRINT 'Hello from print' 
RAISERROR('hello from raierror', 10, 1) 


However, use OSQL with the -m-1 switch, and you will see that the RAISERROR 
is indeed an error message: 
osql /STIBDELL\FRESH /ic:\mailtest.sql /E /n /m-1 


Nevetheless, neither error messages (as in RAISERROR) nor text messages (as 
in PRINT and the result from xp_smtp_sendmail) can be captured at the TSQL 
level. This is an often requested feature, but you might want to request it 
anyhow for future releases: sqlw...@microsoft.com. 


----------------------
Server response: 553 sorry, that domain isn't in my list of allowed rcpthosts (#5.7.1)
An attempt to use "local ISP" SMTP for sending emails from outside IP to outside email... 
	had something like this, hunderd other reasons probably exist

Server response: 451 See http://pobox.com/~djb/docs/smtplf.html.
		SELECT @message = replace(@message, CHAR(10), CHAR(13) + CHAR(10))
*/

AS
--declare a set of standard error logging variables
	DECLARE @proc_name sysname				--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	DECLARE @db_name sysname				-- ----""------
	SELECT 	@proc_name = name, @db_name = db_Name() FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int				--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @log_desc nvarchar(1000)			-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)	-- ----""------

--	SELECT @From , @To, @Subject, @Message --debug

	--log input parameters, it is a valuable info
	SELECT @proc_name = name, @db_name = db_Name() FROM sysobjects WHERE id = @@PROCID	
	SELECT @stmnt_lastexec =   'Input parameters'
	SELECT @log_desc = 	'@From varchar(8000): ' + isNull('''' + @From + '''', 'NULL') + CHAR(10)
				+ '@To varchar(8000): ' + isNull('''' + @To + '''', 'NULL') + CHAR(10)
				+ '@Message varchar(8000): ' + isNull('''' + @Message + '''', 'NULL') + CHAR(10)
				+ '@Server varchar(500): ' + isNull('''' + @Server + '''', 'NULL') + CHAR(10)
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
					@AgentName = @proc_name,
					@Statement = @stmnt_lastexec,
					@RecordCount = @rcnt,
					@LogDesc = 	@log_desc,
					@IsLogOnly = 1

	SELECT 	@stmnt_lastexec = "EXEC @err = master.dbo.xp_smtp_sendmail...", @err = NULL,
		@log_desc = 'Try executing of sproc from QA to see SMTP error code. Or check SQLAgent output file if it was specified in job step advanced options'

	EXEC @err = master.dbo.xp_smtp_sendmail	@From 	= @From,
						@To	= @To,
						@Subject = @Subject,
						@Message = @Message,
						--Valid hostname or IP address pointing an SMTP mail server
						@Server = @Server

--SELECT * FROM SQL_ERR_LOG
--SELECT @err = 1

	
	SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
	IF (@err <> 0) BEGIN
		EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
						@AgentName = @proc_name,
						@Statement = @stmnt_lastexec,
						@ErrCode = @err, 
						@RecordCount = @rcnt,
						@LogDesc = @log_desc,
						@IsWarnOnly = 1
	END
	RETURN @err
GO
