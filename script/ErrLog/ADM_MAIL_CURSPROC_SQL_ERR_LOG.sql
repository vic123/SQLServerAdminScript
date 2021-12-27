SET QUOTED_IDENTIFIER OFF
GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[ADM_MAIL_CURSPROC_SQL_ERR_LOG]') 
		AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[ADM_MAIL_CURSPROC_SQL_ERR_LOG]
GO

CREATE PROCEDURE ADM_MAIL_CURSPROC_SQL_ERR_LOG	--SET QUOTED_IDENTIFIER OFF 
			@SystemName sysname,
			@AgentName sysname = NULL,
			@StatementBeg varchar (2000) = NULL,
			@ErrIdBeg int = NULL, 
			@EmailList varchar(8000),
			@WarnLevel	tinyint,
			@Action nvarchar(30) = NULL,
			@SPId int = NULL
/* Currently - only 2, 5, 6 is supported
WHEN 1 THEN 'DEBUG' 
WHEN 2 THEN 'INFO' 
WHEN 3 THEN 'NOTIFICATION' 
WHEN 4 THEN 'ALERT' 
WHEN 5 THEN 'WARNING' 
WHEN 6 THEN 'ERROR' 
*/
--DROP PROCEDURE [dbo].[ADM_MAIL_CURSPROC_SQL_ERR_LOG]
/**********************************************************************************************
Author		: Victor Blokhin (vic123.com)
Date		: Aug 2006
Purpose		: Sends email message SQL_ERR_LOG records of current sproc and subordinate calls
Referred	: 
**********************************************************************************************/
/*MODIFICATIONS HISTORY IN CHRONOLOGICAL ORDER, WITH THE LATEST CHANGE BEING AT THE TOP.*/ 
/******************************************************************************************** 
MODIFIED BY      : 	Victor Blokhin	
MODIFICATIONS    :	@ErrIdBeg, @SPId parameters - to get messages of another process.
			Inserted @@SERVERNAME into subject
DATE             :	Aug 2006
***********************************/
AS BEGIN
	IF @EmailList IS NULL RETURN 0
--declare a set of standard error logging variables
	DECLARE @proc_name sysname				--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	DECLARE @db_name sysname				-- ----""------
	SELECT 	@proc_name = name, @db_name = db_Name() 
		FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int				--"global" vars for ADM_WRITE_SQL_ERR_LOG
	SELECT @err = 0, @rcnt = 0
	DECLARE @log_desc nvarchar(1000)			-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)	-- 		----""------

	--log input parameters, it is a valuable info
	SELECT @proc_name = name, @db_name = db_Name()
		FROM sysobjects WHERE id = @@PROCID	
	SELECT @stmnt_lastexec =   'Input parameters'
	SELECT @log_desc = '@SystemName sysname: ' + isNull('''' + @SystemName + '''', 'NULL') + CHAR(10)
			+ '@AgentName sysname: ' + isNull('''' + @AgentName + '''', 'NULL') + CHAR(10)
			+ '@StatementBeg varchar (2000): ' + isNull('''' + @StatementBeg + '''', 'NULL') + CHAR(10)
			+ '@ErrIdBeg int: ' + isNull(convert(varchar(100), @ErrIdBeg), 'NULL') + CHAR(10)
			+ '@EmailList varchar (2000): ' + isNull('''' + @EmailList + '''', 'NULL') + CHAR(10)
			+ '@WarnLevel int: ' + isNull(convert(varchar(100), @WarnLevel), 'NULL') + CHAR(10)
			+ '@Action  nvarchar (30): ' + isNull('''' + @Action + '''', 'NULL') + CHAR(10)
			+ '@SPid int: ' + isNull(convert(varchar(100), @SPid), 'NULL') + CHAR(10)

	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
					@AgentName = @proc_name,
					@Statement = @stmnt_lastexec,
					@RecordCount = @rcnt,
					@LogDesc = @log_desc,
					@IsLogOnly = 1
	SET @log_desc = ''

	DECLARE @is_log bit, @is_warn bit
	SELECT @is_log = 1, @is_warn = 1
	IF @WarnLevel > 4 SET @is_log = 0
	IF @WarnLevel > 5 SET @is_warn = 0

	SET @SPId = isNull(@SPId, @@spid)
--SELECT @ErrIdBeg
	IF @ErrIdBeg IS NULL BEGIN
--		SELECT @stmnt_lastexec = "DECLARE @first_err_id int..."
--		DECLARE @first_err_id int
		SELECT @stmnt_lastexec = "SELECT TOP 1 @ErrIdBeg = ErrId FROM SQL_ERR_LOG ..."
		SELECT TOP 1 @ErrIdBeg = ErrId - 1 FROM SQL_ERR_LOG 
			WHERE 	ProcessId = @SPId
				AND SystemName = @SystemName
				AND AgentName = @AgentName
				AND Statement = @StatementBeg
			ORDER BY ErrId DESC
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
	END
--SELECT @ErrIdBeg 

/*
	SELECT isNull(
					'ERROR(' + convert(varchar, nullIf(count(
						CASE
							WHEN IsLogOnly = 1 THEN 0
							WHEN IsWarnOnly = 1 THEN 0
						END
						),0)) 
					+ ')', 
				'')
	FROM SQL_ERR_LOG 
*/
	DECLARE @subject nvarchar(1000)
	IF EXISTS(SELECT * 
			FROM SQL_ERR_LOG
			WHERE ProcessId = @SPId
				AND ErrId > @ErrIdBeg 
				AND (IsLogOnly = @is_log OR IsLogOnly = 0)
				AND (IsWarnOnly = @is_warn OR IsWarnOnly = 0)
			) BEGIN
		SELECT @stmnt_lastexec = "SELECT @subject = @@SERVERNAME + '.' + @SystemName + isNull('.' + @AgentName, '') ..."	
--SELECT @stmnt_lastexec 
		SELECT @subject = isNull(
						'ERR-' + convert(varchar, nullIf(sum(
							CASE
								WHEN IsLogOnly = 1 THEN 0
								WHEN IsWarnOnly = 1 THEN 0
								ELSE 1
							END
							),0)) 
						+ ',', 
					'')
				+ isNull(
						'WARN-' + convert(varchar, nullIf(sum(convert(tinyint,IsWarnOnly)),0)) 
						+ ',', 
					'')
				+ isNull(
						'LOG-' + convert(varchar, nullIf(sum(convert(tinyint,IsLogOnly)),0)) 
						+ ' ', 
					'')
				+ @@SERVERNAME + '.' + @SystemName + isNull('.' + @AgentName, '') + isNull('.' + @Action, '') + ' - '
			FROM SQL_ERR_LOG
			WHERE ProcessId = @SPId
				AND ErrId > @ErrIdBeg 
				AND AgentName <> @proc_name	--don't include this proc logs in email 
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
		SELECT @subject = left(@subject, len(@subject) - 1)


		--concatenate message
		--"parameter" table for SendMail - necessary for messages > 8000
		CREATE TABLE #SendMail_Message (id int IDENTITY, nstr nvarchar(4000)) --070612

		DECLARE @message nvarchar(4000), @msg_lf varchar(4)
		SET @msg_lf = CHAR(10) + CHAR(10) 
		SELECT @stmnt_lastexec = "SELECT @message = isNull(@message + @msg_lf + 'ERROR' + CHAR(10), @msg_lf + 'ERROR' + CHAR(9))..."
--070612		SELECT @message = isNull(@message + @msg_lf + AgentName + ' ERROR' + CHAR(10), @msg_lf + AgentName +  ' ERROR ' + CHAR(10)) 
		INSERT INTO #SendMail_Message (nstr) 
			SELECT @msg_lf + AgentName +  ' ERROR ' + CHAR(10) 
			+ 'Date: ' + CHAR(9) + isNull(convert(varchar(30), DateTime, 121), 'NULL') + ';' + CHAR(10) 
			+ 'Statement: ' + CHAR(9) + isNull(Statement,'') + ';' + CHAR(10) 
			+ 'ErrCode: ' + CHAR(9) + isNull(convert(varchar, ErrCode),'') + '; ' + CHAR(10) 
			+ 'LogDesc: ' + CHAR(9) + isNull(LogDesc,'') + '; ' + CHAR(10) 
			+ 'SysMessage: ' + CHAR(9) + isNull(SysMessage,'') + '.'
			FROM SQL_ERR_LOG 
			WHERE IsLogOnly = 0 AND IsWarnOnly = 0
				AND ProcessId = @SPId
				AND ErrId > @ErrIdBeg 
				AND AgentName <> @proc_name	--don't include this proc logs in email 
			ORDER BY ErrId
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err

--SELECT 'message1 =' + @message 
	
		SELECT @stmnt_lastexec = "SELECT @message = isNull(@message + @msg_lf + 'WARNING' + CHAR(10), @msg_lf + 'WARNING' + CHAR(9)) ..."
--070612		SELECT @message = isNull(@message + @msg_lf + AgentName +  ' WARNING' + CHAR(10), @msg_lf + AgentName +  ' WARNING' + CHAR(10)) 
		INSERT INTO #SendMail_Message (nstr) 
		SELECT @msg_lf + AgentName +  ' WARNING' + CHAR(10) 
			+ 'Date: ' + CHAR(9) + isNull(convert(varchar(30), DateTime, 121), 'NULL') + ';' + CHAR(10) 
			+ 'Statement: ' + CHAR(9) + isNull(Statement,'') + ';' + CHAR(10) 
			+ 'ErrCode: ' + CHAR(9) +isNull(convert(varchar, ErrCode),'') + '; ' + CHAR(10) 
			+ 'LogDesc: ' + CHAR(9) +isNull(LogDesc,'') + '; ' + CHAR(10) 
			+ 'SysMessage: ' + CHAR(9) + isNull(SysMessage,'') + '.'
			FROM SQL_ERR_LOG 
			WHERE IsWarnOnly = 1
				AND ProcessId = @SPId
				AND ErrId > @ErrIdBeg 
				AND AgentName <> @proc_name	--don't include this proc logs in email 
			ORDER BY ErrId
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err

--SELECT 'message2 =' + @message 
		INSERT INTO #SendMail_Message (nstr) VALUES(@msg_lf)
		INSERT INTO #SendMail_Message (nstr) VALUES('All messages in chronological order:')
		INSERT INTO #SendMail_Message (nstr) VALUES('------------------------------------------------')
	
		SELECT @stmnt_lastexec = "SELECT @message = isNull(@message + @msg_lf + 'LOG' + CHAR(10), @msg_lf + 'LOG' + CHAR(9))..."
--070612		SELECT @message = isNull(@message + @msg_lf + AgentName +  ' LOG' + CHAR(10), @msg_lf + AgentName +  ' LOG' + CHAR(10)) 
		INSERT INTO #SendMail_Message (nstr) 
		SELECT @msg_lf + AgentName 
			+  CASE WHEN IsLogOnly = 1 THEN ' LOG' 
			  	WHEN IsWarnOnly = 1 THEN ' WARNING' 
			  	ELSE ' ERROR' 
			END + CHAR(10) 
			+ 'Date: ' + CHAR(9) + isNull(convert(varchar(30), DateTime, 121), 'NULL') + ';' + CHAR(10) 
			+ 'Statement: ' + CHAR(9) + isNull(Statement,'') + ';' + CHAR(10) 
			+ 'LogDesc: ' + CHAR(9) + isNull(LogDesc,'') + '.'
			FROM SQL_ERR_LOG 
--070612			WHERE IsLogOnly = 1
--070612				AND 
			WHERE--070612 
				ProcessId = @SPId
				AND ErrId > @ErrIdBeg 
				AND AgentName <> @proc_name	--don't include this proc logs in email 
			ORDER BY ErrId
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err

--SELECT 'message3 =' + @message 

		SELECT @message = replace(@message, CHAR(10), CHAR(9) + CHAR(13) + CHAR(10))
		--EXEC @err = SMTPSendMail 	@To = @EmailList,
		EXEC SendMail 	@To = @EmailList,
				@Subject = @subject,
				@Message = @message
		--SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
		--IF (@err <> 0) GOTO Err
		--RETURN @err
		--ignore mail sending errors, SMTPSendMail will write warning in log if any occur
	END
	RETURN @err
Err:
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
						@AgentName = @proc_name,
						@Statement = @stmnt_lastexec, 
						@ErrCode = @err, 
						@RecordCount = @rcnt, 
						@LogDesc = @log_desc,
						@EMNotify = NULL, 
						@UserId = NULL

	RETURN isNull(@err, 0)
END
GO


SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO



