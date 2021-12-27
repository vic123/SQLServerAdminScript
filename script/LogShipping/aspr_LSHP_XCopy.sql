SET QUOTED_IDENTIFIER OFF
GO
DROP PROCEDURE aspr_LSHP_XCopy 
GO
CREATE PROCEDURE aspr_LSHP_XCopy @SrcPath nvarchar(255), @DstPath nvarchar(255) 
/*
aspr_LSHP_XCopy 'D:\151Pilot Documents\AssessmentDocuments\*', '\\tiprfs02\shared\BAK_SWAP'
SELECT * FROM SQL_ERR_LOG
aspr_LSHP_XCopy 'E:\Program Files\Borland\Delphi7\Demos\WebServices\*', '\\vic-w2ks\SharedFolder\LogShipping\tmp_dsl;jf  sdlkjf lx  f dd;jkl  df;lk fdd dsf adf sadfasfd asd'
SELECT * FROM SQL_ERR_LOG
aspr_LSHP_XCopy 'E:\Program Files\Borland\Delphi7\Demos\WebServices\*', '\\vic-w2ks\SharedFolder\LogShipping'
aspr_LSHP_XCopy '\\vic-w2ks\SharedFolder\LogShipping\*', '\\vic-w2ks\SharedFolder\'
SELECT * FROM SQL_ERR_LOG
aspr_LSHP_XCopy 'e:\Inetpub\wwwroot\_private\AssessmentDocuments\*', '\\vic-w2ks\SharedFolder\'




Access denied Unable to create directory - \\vic-w2ks\SharedFolder\LogShipping\DBServer Access denied Unable to create directory - \\vic-w2ks\SharedFolder\LogShipping\EchoService Access denied Unable to create directory - \\vic-w2ks\SharedFolder\LogShipping\IssuesSample Access denied Unable to create directory - \\vic-w2ks\SharedFolder\LogShipping\PostTool Access denied Unable to create directory - \\vic-w2ks\SharedFolder\LogShipping\SOAPAttachments Access denied Unable to create directory - \\vic-w2ks\SharedFolder\LogShipping\SOAPDataModule Access denied Unable to create directory - \\vic-w2ks\SharedFolder\LogShipping\SOAPHeaders 0 File(s) copied  

*/

AS BEGIN
SET NOCOUNT ON

	DECLARE @proc_name sysname					--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	SELECT @proc_name = name FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int					--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @logmsg nvarchar(1000)				-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------

	DECLARE @params_info varchar(1000)
	SET @params_info = '@SrcPath nvarchar(255) = ' + isNull('''' + @SrcPath + '''', 'NULL') + CHAR(10)
						+ '@DstPath nvarchar(255) = ' + isNull('''' + @SrcPath + '''', 'NULL')
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'LOGSHIP', 
								@AgentName = @proc_name,
								@Statement = '/**** Input parameters ****/',
								@RecordCount = @rcnt,
								@LogDesc = 	@params_info,
								@UserId = NULL, 
								@IsLogOnly = 1



	DECLARE @exec nvarchar(1000)

	CREATE TABLE #XCopyOut (output nvarchar(4000))

	SELECT @exec = 'xcopy "' + @SrcPath + '" "' + @DstPath + '" /R /Y /D /S /H /K /O /X /C'
	SELECT 	@stmnt_lastexec = "EXEC @err= master..xp_cmdshell @exec"
	INSERT INTO #XCopyOut (output) EXEC @err= master..xp_cmdshell @exec 
		/*
		 /D:m-d-y     Copies files changed on or after the specified date.
		              If no date is given, copies only those files whose 
						source time is newer than the destination time.
		 /R           Overwrites read-only files.
		 /Y           Suppresses prompting to confirm you want to overwrite an existing destination file.
		  /S           Copies directories and subdirectories except empty ones.
		  /H           Copies hidden and system files also.
		  /K           Copies attributes. Normal Xcopy will reset read-only	attributes.
		  /O           Copies file ownership and ACL information.
		  /X           Copies file audit settings (implies /O).
		  /C           Continues copying even if errors occur.
		*/
	SELECT @logmsg = ''
	SELECT @logmsg = @logmsg + isNull(output, '') + CHAR(10) FROM #XCopyOut
	IF @err <> 0 GOTO Err
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'LOGSHIP', 
								@AgentName = @proc_name,
								@Statement = @stmnt_lastexec,
								@RecordCount = @rcnt,
								@LogDesc = 	@logmsg,
								@UserId = NULL, 
								@IsLogOnly = 1
	
	RETURN 0

Err:
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'LOGSHIP', 
								@AgentName = @proc_name,
								@Statement = @stmnt_lastexec, 
								@ErrCode = @err, 
								@RecordCount = @rcnt, 
								@LogDesc = @logmsg,
								@EMNotify = NULL, 
								@UserId = NULL
	RETURN @err
END
GO
SET QUOTED_IDENTIFIER ON
GO

	
