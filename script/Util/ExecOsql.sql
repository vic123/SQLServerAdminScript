SET QUOTED_IDENTIFIER OFF
IF OBJECT_ID('ExecOsql') IS NOT NULL  
  DROP PROC ExecOsql
GO
CREATE PROC ExecOsql 	@Query varchar(4000), --query is converted into straight row before execution, 
						--do not use “—“ comments inside @Query. 
			@DBName sysname = NULL, --context database
			@EmailList varchar(1000), --emails, separated by ","
			@EmailSubject nvarchar(1000) = NULL,
			@WarnLevel tinyint = 0 --1-4 ==log 5==warning, 6==error
/**********************************************************************************************
Author           : Victor Blokhin (vic123.com) 
Date             : Aug 2006
Purpose          : SQL batch execution through osql.exe. 
**********************************************************************************************/
/*MODIFICATIONS HISTORY IN CHRONOLOGICAL ORDER, WITH THE LATEST CHANGE BEING AT THE TOP.*/ 
/******************************************************************************************** 
MODIFIED BY      : 	Victor Blokhin 
MODIFICATIONS    :	Added emailing. Two emails can be generated if @EmailList is not null. 
			First email collects log records of invoked process. It is sent always.
			Second email collects log record of ExecOsql by itself. 
				It is sent only when osql.exe returned <> 0 error status.
			If @EmailSubject is NULL, then it is formed 
				a) if it is a job with single step - from job name	
				b) if it is a job with 1 > steps - from step name
				c) if it is not a job - db_name().ExecOsql.left(@Query, 20)
			@EmailSubject will be the subject of first email - messages from invoked process.
			Subject of second email (if any) is always SQLAdmin.ExecOsql-....
DATE             :	Aug 2006
*/

/*
Used OSQL arquments:
-Q "query" Executes a query and immediately exits osql. Use double quotation marks around the query and single quotation marks around anything embedded in the query.
[-e echo input]
[-S server]
--[-i inputfile]
--[-o outputfile]
[-E trusted connection]
[-I Enable Quoted Identifiers]
[-d use database name]
-m error_level Customizes the display of error messages. The message number, state, and error level are displayed for errors of the specified severity level or higher. Nothing is displayed for errors of levels lower than the specified level. Use -1 to specify that all headers are returned with messages, even informational messages. If using -1, there must be no space between the parameter and the setting (-m-1, not -m -1).
-r {0 | 1} Redirects message output to the screen (stderr). If you do not specify a parameter, or if you specify 0, only error messages with a severity level 17 or higher are redirected. If you specify 1, all message output (including "print") is redirected.
*/
/*
DESCRIPTION:
Executes supplied T-SQL batch through osql.exe command line tool. 
When T-SQL batch is executed directly from SQL Agent, it gets interrupted on any error, making impossible to take any custom notification or logging action.

*/
/*
Tryouts:

	DROP TABLE #OSQOut 
	CREATE TABLE #OSQOut (id int IDENTITY, nstr varchar(4000))
	DECLARE @cmd varchar(4000), @Query varchar(4000)
	SELECT @Query = 'SELECT * FROM sysobjects'
	SELECT @cmd = 'osql -m-1 -r1 -P -e -S ' + @@SERVERNAME + ' -w 4000 -E -Q"' + @Query + '" 2>&1'
	INSERT INTO #OSQOut (nstr) EXEC master.dbo.xp_cmdshell @cmd
	SELECT ASCII(substring(nstr, len(nstr) - 1, 1)) FROM #OSQOut

--SELECT len('SQLAgent - TSQL JobStep (Job '), len('SQLAgent - TSQL JobStep (Job') 
--SELECT 1 WHERE '0x672D9208E48EA944AF32C671E3AD5CD5' LIKE '0x%[^0-9ABCDEF]%'
--SQLAgent - TSQL JobStep (Job 0x672D9208E48EA944AF32C671E3AD5CD5 : Step 1)
waitfor delay '00:00:05'
--select Program_Name, * from master..sysprocesses where  lastwaittype = 'WAITFOR'
*/
/*Test cases:
Run standalone with NULL email subject and NULL @EmailList

Run standalone with NULL email subject 
exec ExecOsql 	@Query='SELECT TOP 3 * FROM sysobjects', 
			@EmailList = 'victor@infoplanet-usa.com',
			@EmailSubject = NULL

Run standalone with email subject 
exec ExecOsql 	@Query='SELECT TOP 3  FROM sysobjects', 
			@EmailList = 'victor@infoplanet-usa.com',
			@EmailSubject = 'SELECT TOP 3 * FROM sysobjects'

SET QUOTED_IDENTIFIER OFF
EXECOsql @Query="
EXEC ArchiveCDRData @MonthsOldToKeep = 13, @EmailList = 'victor@infoplanet-usa.com'
", 
			@EmailList = 'victor@infoplanet-usa.com',
			@EmailSubject = '@MonthsOldToKeep = 15'

SET QUOTED_IDENTIFIER OFF
EXECOsql @Query="
EXEC ArchiveCDRData @MonthsOldToKeep = 13
", 
			@EmailList = 'victor@infoplanet-usa.com',
			@EmailSubject = NULL



Run standalone with NULL email subject, get email 
exec ExecOsql 	@Query='SELECT TOP 3 * FROM sysobjects raiserror (''sdlksjflsdjkf'', 16, -1)', 
			@EmailList = 'victor@infoplanet-usa.com',
			@EmailSubject = NULL


Run as a job with NULL email subject


Simulate error when cannot parse spid, err_id_beg (overall statement error?). 
exec ExecOsql 	@Query='SELECT TOP 3 FROM sysobjects', 
			@EmailList = NULL,
			@EmailSubject = NULL
SELECT TOP 100 * FROM SQL_ERR_LOG ORDER BY ErrId DESC

Get an email with messages.
exec ExecOsql 	@Query='SELECT TOP 3 FROM sysobjects', 
			@EmailList = 'victor@infoplanet-usa.com',
			@EmailSubject = NULL
581


Simulate breaking error (create existing table). Get errlog and output in 2 mails.






EXEC ExecOsql 	@Query = 'SELECT * FROM Customers', 
		@DBName = 'Northwind'

SELECT TOP 100 * FROM SQL_ERR_LOG ORDER BY ErrId DESC
*/

AS BEGIN
--declare a set of standard error logging variables
	DECLARE @proc_name sysname				--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	DECLARE @db_name sysname				-- ----""------
	SELECT 	@proc_name = name, @db_name = db_Name() FROM sysobjects WHERE id = @@PROCID
			
	DECLARE @err int, @rcnt int				--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @log_desc varchar(5300)			-- ----""------
	DECLARE @stmnt_lastexec varchar(255)	-- ----""------

	SELECT @proc_name = name, @db_name = db_Name()
		FROM sysobjects WHERE id = @@PROCID	
	SELECT @stmnt_lastexec =   'Input parameters'
	SELECT @log_desc = 	'@Query varchar(4000): ' + isNull('''' + @Query + '''', 'NULL') + CHAR(10)
				+ '@DBName sysname: ' + isNull('''' + @DBName + '''', 'NULL') 
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
					@AgentName = @proc_name,
					@Statement = @stmnt_lastexec,
					@RecordCount = @rcnt,
					@LogDesc = 	@log_desc,
					@IsLogOnly = 1



	IF @EmailSubject IS NULL BEGIN	
	--construct @EmailSubject from job or step (when > 1) name. 
	--Job identifier is saved in process_name of master.dbo.sysprocesses
		DECLARE @program_name nvarchar(1000), @sql nvarchar(1000),
			@job_id_u uniqueidentifier, @job_id_c varchar(100), --, @job_id_b varbinary(100)
			@step_c varchar(10), @step_i int

		SELECT @program_name = program_name from master..sysprocesses WHERE spid = @@spid
		SELECT @stmnt_lastexec =   "IF patindex ('SQLAgent - TSQL JobStep (Job %', @program_name) <> 1 GOTO NotAJob",
			@log_desc = @program_name
		IF patindex ('SQLAgent - TSQL JobStep (Job %', @program_name) <> 1 GOTO NotAJob

		SELECT @job_id_c = substring (@program_name, 
						len('SQLAgent - TSQL JobStep (Job')+ 2, 
						34
						)
		SELECT @stmnt_lastexec =   "IF EXISTS (SELECT 1 WHERE @job_id_c LIKE '0x%[^0-9ABCDEF]%') GOTO NotAJob"
		IF EXISTS (SELECT 1 WHERE @job_id_c LIKE '0x%[^0-9ABCDEF]%') GOTO NotAJob
		
		SELECT @stmnt_lastexec =   "select @sql = 'SELECT @UID = ' + @job_id_c"
		select @sql = 'SELECT @UID = ' + @job_id_c
		EXEC @err = sp_executesql @sql, N'@UID uniqueidentifier OUTPUT', @job_id_u OUTPUT 
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
		IF @err <> 0 GOTO NotAJob
		
		IF (SELECT count(*) FROM msdb..sysjobsteps WHERE job_id = @job_id_u) > 1 BEGIN
			SELECT @stmnt_lastexec =   "IF substring(@program_name, ..."
			IF substring(@program_name, 
					len('SQLAgent - TSQL JobStep (Job 0x672D9208E48EA944AF32C671E3AD5CD5')+ 2, 
					6) 
				<> ': Step' GOTO NotAJob
			
			SELECT @step_c = substring (@program_name, 
						len('SQLAgent - TSQL JobStep (Job 0x672D9208E48EA944AF32C671E3AD5CD5 : Step') + 1, 
						len(@program_name)
					)
			SELECT @step_c = left(@step_c, len(@step_c) - 1)
			SELECT @stmnt_lastexec =   "IF isNumeric(@step_c) <> 1 GOTO NotAJob"
			IF isNumeric(@step_c) <> 1 GOTO NotAJob
			SELECT @step_i = convert(int, @step_c)
			
			SELECT @EmailSubject = step_name FROM msdb..sysjobsteps 
				WHERE job_id = @job_id_u AND step_id = @step_i
			
		END ELSE BEGIN
--SELECT * FROM msdb..sysjobs ORDER BY NAME
			SELECT @EmailSubject = name FROM msdb..sysjobs
				WHERE job_id = @job_id_u 
		END
			
		SELECT @stmnt_lastexec =   "IF @EmailSubject IS NULL GOTO NotAJob; " 
			+ isNull(convert(varchar(1000), @job_id_u), 'NULL') + "; " 
			+ @job_id_c
		IF @EmailSubject IS NULL GOTO NotAJob
		
		GOTO RunQuery
		
	NotAJob:
		EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
						@AgentName = @proc_name,
						@Statement = @stmnt_lastexec,
						@RecordCount = @rcnt,
						@LogDesc = @log_desc,
						@IsWarnOnly = 1
		SELECT @EmailSubject = @db_name + '.' + @proc_name + isNull('.' + left(@Query, 20), '')
	END

RunQuery:

	SELECT @DBName = isNull(@DBName, db_name())

	CREATE TABLE #OSQLOut (id int IDENTITY, nstr varchar(255))
	DECLARE @osql_err int 
	DECLARE @cmd varchar(4000)
--SELECT @Query
--	SELECT @Query = 'PRINT ''@@SPID = '' convert(varchar(20), @@SPID) ' + @Query 
	SELECT @Query = 'SELECT  @@SPID AS SPID, max(ErrId) AS ErrIdBeg FROM ' + db_name() + '..SQL_ERR_LOG ' + @Query 
	SELECT @Query = replace (@Query, CHAR(13) + CHAR(10), ' ')
--	SELECT @Query = replace (@Query, CHAR(10), ' ')
--SELECT @Query
	-- -e puts input in front of spid and err_id_beg
	SELECT @cmd = 'osql -b -m-1 -r1 -S ' + @@SERVERNAME + ' -d ' + @DBName + ' -w 4000 -E -Q"' + @Query + '" 2>&1'
--SELECT @cmd
	SELECT @stmnt_lastexec =   'INSERT INTO #OSQOut (nstr) EXEC @err = master.dbo.xp_cmdshell @sql', 
		@log_desc = @cmd
	INSERT INTO #OSQLOut (nstr) EXEC @err = master.dbo.xp_cmdshell @cmd
	SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
--SELECT @@ERROR
--SELECT @err

	
	DECLARE @is_log int
	SET @is_log = 1
	IF @err <> 0 SET @is_log = 0
 

	SET @osql_err = @err
--SELECT * FROM 	#OSQLOut
	SELECT @log_desc = left(isNull (@log_desc + CHAR(10), '') 
				+ isNull(nstr, 'NULL'), 5300)
		FROM #OSQLOut ORDER BY id

	IF @log_desc IS NULL BEGIN 
		SELECT @log_desc = '#OSQLOut rows count:' + convert(varchar(100), count(*)) + ' ' + CHAR(10)
			FROM #OSQLOut
		SELECT @log_desc = @log_desc + '#OSQLOut non-NULL rows count:' + convert(varchar(100), count(*)) 
			FROM #OSQLOut WHERE nstr IS NOT NULL
	END


--SELECT @log_desc
--SELECT * FROM #OSQLOut
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
					@AgentName = @proc_name,
					@Statement = @stmnt_lastexec, 
					@ErrCode = @err, 
					@RecordCount = @rcnt, 
					@LogDesc = @log_desc,
					@EMNotify = NULL, 
					@UserId = NULL,
					@IsLogOnly = @is_log


	declare @out_row nvarchar(255), 
		@spid_c varchar(20), @spid_i int, 
		@err_id_beg_c varchar(20), @err_id_beg_i int
	--get spid and err_id_beg
	SELECT @out_row = rtrim(ltrim(nstr)) FROM #OSQLOut WHERE id = 1
	SELECT @stmnt_lastexec =   "IF patindex('SPID' + CHAR(9) + 'ErrIdBeg%', @out_row) <> 1 GOTO Err_Parse", 
		@log_desc = @out_row
	IF patindex('SPID%ErrIdBeg', @out_row) <> 1 GOTO Err_Parse
--
SELECT patindex('SPID%ErrIdBeg', convert(varchar, NULL))
IF patindex('SPID%ErrIdBeg', convert(varchar, NULL)) <> 1 SELECT 'sdfsd'

	SELECT @out_row = rtrim(ltrim(nstr)) FROM #OSQLOut WHERE id = 3
	
	SELECT @spid_c = left(ltrim(@out_row), charindex( ' ', @out_row))
	SELECT @stmnt_lastexec =   "IF isNumeric(@spid_c) <> 1 GOTO Err_Parse", 
		@log_desc = isNull(@out_row, '@out_row IS NULL')  + '; ' + isNull(@spid_c, '@spid_c IS NULL')
	IF isNumeric(@spid_c) <> 1 GOTO Err_Parse
IF isNumeric(NULL) <> 1 SELECT 'sdfsd'

	SET @spid_i = convert(int, @spid_c)
	
	SELECT @err_id_beg_c = ltrim(right(@out_row, len(@out_row) - len(@spid_c)))
	SELECT @stmnt_lastexec =   "IF isNumeric(@err_id_beg_c) <> 1 GOTO Err_Parse", @log_desc = @out_row + '; ' + @err_id_beg_c
	IF isNumeric(@err_id_beg_c) <> 1 GOTO Err_Parse
	SET @err_id_beg_i = convert(int, @err_id_beg_c)

Email:
	SELECT @stmnt_lastexec = "EXEC @err = ADM_MAIL_CURSPROC_SQL_ERR_LOG @SystemName = @EmailSubject,..."
	EXEC ADM_MAIL_CURSPROC_SQL_ERR_LOG @SystemName = @EmailSubject,
--						@AgentName = @proc_name,
--						@StatementBeg = 'Input parameters',
						@ErrIdBeg = @err_id_beg_i,
						@EmailList = @EmailList,
						@WarnLevel = @WarnLevel,
						@SPId = @spid_i

	IF (@is_log = 1) RETURN 0
	ELSE GOTO Err_Mail

Err_Parse:
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
					@AgentName = @proc_name,
					@Statement = @stmnt_lastexec, 
					@ErrCode = @err, 
					@RecordCount = @rcnt, 
					@LogDesc = @log_desc,
					@EMNotify = NULL, 
					@UserId = NULL,
					@IsWarnOnly = 1
Err_Mail:
	EXEC ADM_MAIL_CURSPROC_SQL_ERR_LOG @SystemName = @dbname,
						@AgentName = @proc_name,
						@StatementBeg = 'Input parameters',
						@EmailList = @EmailList,
						@WarnLevel = @WarnLevel
	RETURN @osql_err
END
GO
	



