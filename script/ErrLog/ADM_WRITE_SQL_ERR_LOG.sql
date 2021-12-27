IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[ADM_WRITE_SQL_ERR_LOG]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[ADM_WRITE_SQL_ERR_LOG]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

CREATE   PROCEDURE ADM_WRITE_SQL_ERR_LOG (
		@SystemName varchar(15),
		@AgentName sysname,
		@Statement varchar(255),
		@ErrCode int = NULL,
		@RecordCount int = NULL,
--		@LogDesc varchar(8000) = NULL,
		@LogDesc varchar(5300) = NULL,
		@EMNotify varchar(255) = NULL,
		@UserId sysname = NULL,
		@IsWarnOnly bit = 0,
		@IsLogOnly bit = 0) AS 

BEGIN

/**********************************************************************************************
Procedure Name   : ADM_WRITE_SQL_ERR_LOG
Author           : Victor Blokhin (vic123.com) & Vlad Isaev (infoplanet-usa.com)
Date             : Jan 2005
Purpose          : Log and error messages saving procedure
Tables Referred  : 
Input Parameters : 
		@SystemName varchar(15): 			some free top level system indentification (usually use db_Name() in place)
		@AgentName sysname: 				some free sublevel system indentification (usually use proc name in place)
		@Statement varchar(255): 			tag/identification of statement or code block from where an error or message originated
		@ErrCode int = NULL: 				an @@ERROR or some custom code
		@RecordCount int = NULL: 			usually @@ROWCOUNT
		@LogDesc varchar(8000) = NULL: 	actually an error or message
		@EMNotify varchar(255) = NULL: 		emails list for notification 
		@UserId sysname = NULL: 			some custom user name (came down from ASP frontend for example)
		@IsWarnOnly bit = 0:				warning flag, meaning that rollback will not be performed
		@IsLogOnly bit = 0:					infoonly flag, meaning that rollback will not be performed
Output Parameters:
**********************************************************************************************/
/*MODIFICATIONS HISTORY IN CHRONOLOGICAL ORDER, WITH THE LATEST CHANGE BEING AT THE TOP.*/ 
/******************************************************************************************** 
MODIFIED BY      : 	Victor Blokhin 
MODIFICATIONS    :	Changed EXEC sp_EmailAlert2 to SendMail 
			CREATE  INDEX [SQL_ERR_LOG__DateTime] ON [dbo].[SQL_ERR_LOG]([DateTime]) ON [PRIMARY]
			CREATE  INDEX [SQL_ERR_LOG__SystemName] ON [dbo].[SQL_ERR_LOG]([SystemName]) ON [PRIMARY]
			CREATE  INDEX [SQL_ERR_LOG__AgentName] ON [dbo].[SQL_ERR_LOG]([AgentName]) ON [PRIMARY]
DATE             :	Aug 2006


MODIFIED BY      : 	Victor Blokhin 
MODIFICATIONS    :	Removed Left(@LogDesc, 900) truncation from SET @EMMsg 
DATE             :	Apr 2006

MODIFIED BY      : 	Victor Blokhin 
MODIFICATIONS    :	Complemented finally raised @errmsg with @ErrCode and @Statement
DATE             :	Mar 2006

MODIFIED BY      : 	Victor Blokhin 
MODIFICATIONS    :	Removed DtComm parameter and table field
DATE             :	Nov 2005

MODIFIED BY      : 	Vlad Isaev 
MODIFICATIONS    :	Integrated emailing
DATE             :	Nov 2005

MODIFIED BY      : 	Victor Blokhin 
MODIFICATIONS    :	Integrated with GetErrorStringSP (lately renamed to ADM_GET_SYS_MESSAGE).
DATE             :	Mar 2005

**********************************************************************************************/  

/*OVERALL T-SQL SCRIPT DESCRIPTION*/ 
/**************************************************************************** 
Error handling and logging in stored procedures.
****************************************************************************/

/**************************************************************************** 
Brief description:
Script is for practical unified handling of errors and logging in stored procedures, 
especially handly in critical background tasks.

ADM_WRITE_SQL_ERR_LOG sproc writes into SQL_ERR_LOG table input parameters.

If @IsWarnOnly AND @IsLogOnly are 0 then ADM_WRITE_SQL_ERR_LOG performs rollback with 
	preserving of rows stored in SQL_ERR_LOG by current transaction (*). 
Such "internal" rollback results in one more warning in error stack - 
	msg 266 - different trancount after execute.
Also in this (error level) case @LogDesc as a message text is explicitly raised, 
	so some bunch of errors may appear.
(*) - IMPORTANT: When XACT_ABORT is set ON log will (can) not be 
	preserved after run-time error rollbacks.

Supplimentary info saved:
	getDate(), suser_sname(), db_Name() (of ADM_WRITE_SQL_ERR_LOG), @@spid, @@NESTLEVEL, @tran_id, @@TRANCOUNT
Also sysmessage text is tried to be extracted with Amit Jethva approach found at 
	http://www.sqlservercentral.com/columnists/ajethva/capturingtheerrordescriptioninastoredprocedure.asp,
	but it is possible to get it only for messages with logging turned on
	(update master.dbo.sysmessages set dlevel = dlevel | 0x80 [WHERE ....] - see "Test:")

ADM_RPT_SQL_ERR_LOG procedure is "helper" for SELECT FROM SQL_ERR_LOG. 
	Exec ADM_RPT_SQL_ERR_LOG 'help' to see parameters that it takes.

sp_EmailAlert2 is testing stub only - replace it with your favourite 
	emailing approach and you'll get emails for records with @EMNotify turned on.
Another approach is to schedule separate task(s) that will dig for critical errors 
	in SQL_ERR_LOG table and do emailing.

See "Sample calls:" for quick start.
****************************************************************************/

/***************************************************************************
Test:
--Simulate primary key violation:
IF (isNull(OBJECT_ID('tempdb..#ADM_WRITE_SQL_ERR_LOG_TST', 'U'),0) <> 0)
	DROP TABLE #ADM_WRITE_SQL_ERR_LOG_TST 
CREATE TABLE #ADM_WRITE_SQL_ERR_LOG_TST (a int PRIMARY KEY)
DECLARE @err int, @rcnt int
BEGIN TRAN
INSERT INTO #ADM_WRITE_SQL_ERR_LOG_TST VALUES (1)
INSERT INTO #ADM_WRITE_SQL_ERR_LOG_TST VALUES (2)
INSERT INTO #ADM_WRITE_SQL_ERR_LOG_TST VALUES (1)
SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
EXEC ADM_SQL_ERR_LOG.dbo.ADM_WRITE_SQL_ERR_LOG 	
							@SystemName = 'TEST', @AgentName = 'TEST', 
							@Statement = 'INSERT INTO #ADM_WRITE_SQL_ERR_LOG_TST VALUES (1)', 
							@ErrCode = @err,
							@RecordCount = @rcnt,
							@LogDesc = 'TEST'
SELECT TOP 1 * FROM ADM_SQL_ERR_LOG.dbo.SQL_ERR_LOG ORDER BY ErrId DESC
SELECT @@TRANCOUNT

--To see error text in SysMessage column
--optionally preserve sysmessages copy
SELECT * INTO master.dbo.sysmessages_org FROM master.dbo.sysmessages
--and run line by line
exec sp_configure N'allow updates', 1
reconfigure with override
UPDATE master.dbo.sysmessages SET dlevel = dlevel | 0x80 WHERE error = 2627
exec sp_configure N'allow updates', 0
reconfigure with override

--sp_executesql - how to get returned error
DROP Proc P
CREATE Proc p
AS BEGIN
	raiserror(14000, 10, -1)
--	SELECT 6
	RETURN 123
END

declare @err int, @exerr int  
EXEC @err = P
SELECT @err, @@ERROR
EXEC @exerr = sp_executesql N'EXEC @err = P',
			N'@err int OUTPUT', 
			@err OUTPUT 
SELECT @err, @exerr, @@ERROR

declare @err int, @exerr int  
EXEC @err = P
SELECT @err, @@ERROR
EXEC @exerr = sp_executesql N'EXEC @err = P IF (@err <> 0) RETURN EXEC @err = P SET @err = 56',
			N'@err int OUTPUT', 
			@err OUTPUT 
SELECT @err, @exerr, @@ERROR



*/

/*****************************************************************************
Sample calls:

SET QUOTED_IDENTIFIER OFF

--declare a set of standard error logging variables
	DECLARE @proc_name sysname				--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	DECLARE @db_name sysname				-- ----""------
	SELECT 	@proc_name = name, @db_name = db_Name() FROM sysobjects WHERE id = @@PROCID
			
	DECLARE @err int, @rcnt int				--"global" vars for ADM_WRITE_SQL_ERR_LOG
	SELECT @err = 0, @rcnt = 0
	DECLARE @log_desc varchar(8000)			-- ----""------
	DECLARE @stmnt_lastexec varchar(255)	-- ----""------
--for OA errors
	DECLARE @hr_obj int							-- var for OAGetErrorInfo
	DECLARE @hr int								-- HRESULT


--optionally log input parameters, it is a valuable info
	SELECT @proc_name = name, @db_name = db_Name() FROM sysobjects WHERE id = @@PROCID	
	SELECT @stmnt_lastexec =   'Input parameters'
	SELECT @log_desc = 	'@CharParam varchar(100): ' + isNull('''' + @CharParam + '''', 'NULL') + CHAR(10)
						+ '@IntParam int: ' + isNull(convert(varchar(100), @IntParam), 'NULL') + CHAR(10)
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
					@AgentName = @proc_name,
					@Statement = @stmnt_lastexec,
					@RecordCount = @rcnt,
					@LogDesc = 	@log_desc,
					@IsLogOnly = 1

--sample statement error handling (notice QUOTED_IDENTIFIER OFF at very begining)
	SELECT @stmnt_lastexec = "INSERT INTO SomeTable VALUES ('SomeValue1', 'SomeValue2')"
	INSERT INTO SomeTable VALUES ('SomeValue1', 'SomeValue2')
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0 OR @rcnt <> 1) GOTO Err

--sample exec sproc error handling (notice more complicated @err assingment)
	SELECT 	@stmnt_lastexec = "EXEC SomeProc", 
			@err = NULL
	EXEC @err = SomeProc
	--	raises "special" error -4711 if return value from sproc is NULL 
	--	(which is not alright in any case) and @@ERROR is 0 by some magic 
	-- 	see http://www.sommarskog.se/error-handling-II.html, http://www.sommarskog.se/error-handling-I.html#linked-servers
	--	"-4711" is suggested "magic number" from first link
	--	@err = NULL assingment before call also covers 
	--	regular stored procedure or dynamic SQL scope-abortion case 
	--	(http://www.sommarskog.se/error-handling-I.html#scope-abortion)
	--	thus this looks like most comprehensive error checking of stored procedure call, 
	--	but while I'm using copy/paste approach then trying to shrink variants rather then their characters
	SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

--sp_executesql
--As of Erland Sommarskog, return value from sp_executesql appears to always be the final value of @@error,
--and therefor we are not interested in it
		SELECT @exec_str = 'EXEC @err = ' + @check_proc_name + ' @em_subj OUTPUT, @em_body OUTPUT'
		SELECT 	@stmnt_lastexec = "EXEC sp_executesql 	@exec_str, ...", 
				@err = NULL, 
				@log_desc = '@check_proc_name: ' + @check_proc_name
		EXEC sp_executesql 	@exec_str, 
							N'@err int OUTPUT, @em_subj varchar(100) OUTPUT, @em_body varchar (4000) OUTPUT', 
							@err OUTPUT, @em_subj OUTPUT, @em_body OUTPUT
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT


--"minimistic" error checking 
	SELECT 	@stmnt_lastexec = "	DECLARE LogFilePath_cur CURSOR FOR ...", 
			@err = -1
	DECLARE LogFilePath_cur CURSOR FOR 
		SELECT Path FROM atbl_CL4F_LogFilePath ORDER BY Path
	IF (@@ERROR <> 0) GOTO Err
	DECLARE @path varchar(500)
	OPEN LogFilePath_cur
	IF (@@ERROR <> 0) GOTO Err

--OA errors
	DECLARE @hr_obj int							-- var for OAGetErrorInfo
	DECLARE @hr int								-- HRESULT

	SELECT 	@hr_obj = @fso,						--copy objecttoken to be used into @hr_obj
			@stmnt_lastexec = "EXEC @hr = sp_OAMethod @fso,'DeleteFile', NULL, @Path"
	EXEC @hr = sp_OAMethod @fso,'DeleteFile', NULL, @file_path
	IF (@hr <> 0) GOTO OAErr

--success end 
	RETURN 0

--OA error handler
OAErr:
	SET @log_desc = isNull(@log_desc, '') + dbo.OAGetErrorInfo (@hr_obj, @hr) 
--	SELECT @log_desc 
	SET @err = @hr
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


******************************************************************************/

	SET NOCOUNT ON

	DECLARE @is_rollbacked bit
	DECLARE @tran_id varchar(255)
	DECLARE @tran_count int
	DECLARE @sys_message varchar(500)
	DECLARE @LastErrLogID int
	DECLARE @EMSubject varchar(200)
	DECLARE @EMMsg varchar(1000)

	SET @is_rollbacked = 0
	SET @tran_count = @@TRANCOUNT

/*(vic-110505) - ?? as far as remember was not quite informative with SQL 2000 (or some low level sys flags had to be touched) and (!!) incopatible with 2005 
	IF (@IsLogOnly = 0 AND @ErrCode IS NOT NULL) BEGIN
		EXEC ADM_GET_SYS_MESSAGE @ErrCode, @sys_message OUTPUT
	END
*/
--(070417)	IF (@IsLogOnly = 0) BEGIN
--(070417)		SELECT @LogDesc = isNull(@LogDesc, 'No description. Check ErrCode (= '
--(070417)				+ isNull(convert(varchar(20), @ErrCode), 'NULL') + ')'
--(070417)				+ ', RecordCount (= ' + isNull(convert(varchar(20), @RecordCount), 'NULL') + ')'
--(070417)				+ ' and SysMessage fields'
--(070417)				)
--(070417)	END
	--(VB-060327)DECLARE @errmsg nvarchar(300)
	DECLARE @errmsg varchar(400), @roll_str varchar(100)	--(VB-060327) - raiserror max
	SET @roll_str = ''
--(070417)	SET @errmsg = left(isNull(@LogDesc, ''), 350)

	IF (@@TRANCOUNT > 0) BEGIN
		exec sp_getbindtoken @tran_id OUTPUT
		IF (@IsWarnOnly = 0 AND @IsLogOnly = 0) BEGIN
		
			-- Save existing batch log into table variable
			DECLARE @ErrLog	TABLE (
				ErrId	            int,
				DateTime			datetime NOT NULL,
				DateDay				int NOT NULL,
				SystemName			sysname NOT NULL,
				AgentName			sysname NOT NULL,
				Statement			varchar(255) NOT NULL,
				ErrCode				int NULL,
				RecordCount			int NULL,
				LogDesc				varchar(5300) NULL,
				SysMessage			varchar(500) NULL,
				EMNotify			varchar(255) NULL,
				--(051122)			DtComm		varchar(2000) NULL,
				UserId				sysname NULL,
				DBLoginName			sysname NOT NULL,
				DBName				sysname NOT NULL,
				ProcessId			int	NOT NULL,
				NestLevel			tinyint NULL,
				TranId 				varchar(255),
				TranCount			int NULL,
				IsRollbacked			bit NOT NULL,
				IsWarnOnly			bit NOT NULL,
				IsLogOnly			bit NOT NULL
			)
			INSERT INTO @ErrLog	(ErrId, DateTime, DateDay, SystemName, AgentName, Statement, ErrCode, RecordCount, LogDesc, SysMessage, EMNotify,
			--(051122)		 					DtComm,
						UserId, DBLoginName, DBName, ProcessId, NestLevel, TranId, TranCount, IsRollbacked, IsWarnOnly, IsLogOnly)
			SELECT ErrId, DateTime, DateDay, SystemName, AgentName, Statement, ErrCode, RecordCount, LogDesc, SysMessage, EMNotify,
			--(051122)							 DtComm,
						UserId, DBLoginName, DBName, ProcessId, NestLevel, TranId, TranCount, IsRollbacked, IsWarnOnly, IsLogOnly
			FROM SQL_ERR_LOG
			WHERE TranId = @tran_id AND DateDay > convert(int, getDate()) - 2
			
			
			/*	Server: Msg 266, Level 16, State 2, "can be ignored because it only sends
				a message to the client and does not affect execution."
			 */
			ROLLBACK TRANSACTION
			
			-- Restore batch log in SQL_ERR_LOG
			SET IDENTITY_INSERT SQL_ERR_LOG ON
			INSERT INTO SQL_ERR_LOG (ErrId, DateTime, DateDay, SystemName, AgentName, Statement, ErrCode, RecordCount, LogDesc, SysMessage, EMNotify,
			--(051122)			 				DtComm,
									UserId, DBLoginName, DBName, ProcessId, NestLevel, TranId, TranCount, IsRollbacked, IsWarnOnly, IsLogOnly)
			SELECT ErrId, DateTime, DateDay, SystemName, AgentName, Statement, ErrCode, RecordCount, LogDesc, SysMessage, EMNotify,
			--(051122)	 						DtComm,
									UserId, DBLoginName, DBName, ProcessId, NestLevel, TranId, TranCount, IsRollbacked, IsWarnOnly, IsLogOnly
			FROM @ErrLog
			SET IDENTITY_INSERT SQL_ERR_LOG OFF
				
			SET @is_rollbacked = 1
--(070417)			SET @errmsg = @errmsg + ' (ROLLBACKED)'
			SET @roll_str = ' (ROLLBACKED)'
		END

	END

	SET @errmsg = 	'@ErrCode:	' + isNull(convert(varchar(10), @ErrCode), 'NULL') + '; ' + CHAR(10)	--(070417)
			+ '@Statement:	' + isNull(left(@Statement, 100), 'NULL') + '; ' + CHAR(10)		--(070417)

	SET @EMMsg = @errmsg

	IF len(@LogDesc) > (400 - len(@errmsg) - len(@roll_str)) BEGIN					--(070417)
		SET @errmsg = @errmsg + '@LogDesc:	' + left(isNull(@LogDesc, ''), 100) + CHAR(10) --(070417)
		+ '...'	+ CHAR(10) --(070417)
		SET @errmsg = @errmsg + right(@LogDesc, (400 - len(@errmsg) - len(@roll_str)))		--(070417)
	END ELSE SET @errmsg = isNull(@LogDesc, '')								--(070417)

	IF len(@LogDesc) > (1000 - len(@EMMsg) - len(@roll_str)) BEGIN					--(070417)
		SET @EMMsg = @EMMsg + '@LogDesc:	' + left(isNull(@LogDesc, ''), 400) + CHAR(10) --(070417)
		+ '...'	+ CHAR(10) --(070417)
		SET @EMMsg = @EMMsg + right(@LogDesc, (1000 - len(@EMMsg) - len(@roll_str)))		--(070417)
	END ELSE SET @EMMsg = isNull(@LogDesc, '')							--(070417)

/*
SELECT getDate(), convert(int, getDate()), @SystemName, @AgentName, @Statement, @ErrCode, @RecordCount, 
--(070412)	@LogDesc, 
	Left(@LogDesc, 5300), 
	@sys_message, @EMNotify,
--(051122)				 @DtComm,
@UserID, suser_sname(), db_Name(), @@spid, @@NESTLEVEL, @tran_id, @@TRANCOUNT, @is_rollbacked, @IsWarnOnly, @IsLogOnly
*/
--SELECT @sys_message

	INSERT INTO SQL_ERR_LOG (DateTime, DateDay, SystemName, AgentName, Statement, ErrCode, RecordCount, LogDesc, 
	--(070412)				
		SysMessage, 
						EMNotify,
	--(051122)				DtComm,
		UserId, DBLoginName, DBName, ProcessId, NestLevel, TranId, TranCount, IsRollbacked, IsWarnOnly, IsLogOnly)
	SELECT getDate(), convert(int, getDate()), @SystemName, @AgentName, @Statement, @ErrCode, @RecordCount, 
	--(070412)	@LogDesc, 
		Left(@LogDesc, 5300), 
	--(070412)	
		@sys_message, 
		@EMNotify,
	--(051122)				 @DtComm,
	@UserID, suser_sname(), db_Name(), @@spid, @@NESTLEVEL, @tran_id, @@TRANCOUNT, @is_rollbacked, @IsWarnOnly, @IsLogOnly

	SET @LastErrLogID = @@identity
--051129vi
	-- Send Email to @EMNotify list (tweak this list-parsing/em flag later, not a priority...)
		IF  @EMNotify is not NULL BEGIN
			SET @EMSubject = @SystemName + '; ' + @AgentName + ' ; LogID:' + cast (@LastErrLogID as varchar)
--(060403)			SET @EMMsg = @Statement + Left(@LogDesc, 900) 
--(070417)	SET @EMMsg = @Statement + Left(@LogDesc, 5300) --(070412)
--			SET @EMMsg = @Statement + CHAR(10) + CHAR(10) + @LogDesc
--SELECT '@EMSubject = ' + @EMSubject, @EMMsg, @EMNotify, @errmsg
		 	EXEC 	SendMail @Subject =@EMSubject,
					@Message = @EMMsg,
					@To = @EMNotify
		END

		IF (@IsWarnOnly = 0 AND @IsLogOnly = 0) BEGIN
			--(VB-060327)
--			SELECT '@ErrCode:	' + isNull(convert(varchar(10), @ErrCode), 'NULL') + '; ' + CHAR(10)
--				+ '@Statement:	' + isNull(@Statement, 'NULL') + '; ' + CHAR(10)
--				+ '@LogDesc:	' + isNull(@LogDesc, 'NULL')


--(070417)			SET @errmsg = 	'@ErrCode:	' + isNull(convert(varchar(10), @ErrCode), 'NULL') + '; ' + CHAR(10)
--(070417)					+ '@Statement:	' + isNull(left(@Statement, 100), 'NULL') + '; ' + CHAR(10)
--(070417)					+ '@LogDesc:	' + isNull(left(@errmsg, 200), 'NULL')
			raisError(@errmsg, 16, 1)
		END
END


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO
