-- EXEC aspr_LS_DelOldFiles_ExtExceptions  'D:\DM_BAK_SW_ARCH', 7
   SET QUOTED_IDENTIFIER OFF
go
--DROP PROCEDURE  aspr_LS_DelOldFiles_ExtExceptions
CREATE  PROCEDURE aspr_LS_DelOldFiles_ExtExceptions
@Path nvarchar(255),
@DaysOld int,
@ExtException1 varchar(4) = NULL ,
@ExtException2 varchar(4) = NULL,	--(060425) in form '.ext'
@SystemName_Log varchar (20) = "Default"

/* COMPILATION INSTRUCTIONS:
   first run statement
   SET QUOTED_IDENTIFIER OFF
   After the end of proc do
   SET QUOTED_IDENTIFIER ON */
/*
test:
----
EXEC aspr_LS_DelOldFiles_ExtExceptions 'D:\tmp\', 10
EXEC aspr_LS_DelOldFiles_ExtExceptions 'D:\tmp\', 10, '.bat', '.doc'
SELECT * FROM SQL_ERR_LOG order by Errid Desc
*/

/**********************************************************************************************
Author			: Vlad Isaev/infoplanet-usa.com
Author 2		: Victor Blokhin/vic123.com
Date			: Dec 2005
Purpose			: To delete files older than X days
			: Part of DriveFreeSpaceControl sp set, can be executed standalone too.
Tables Referred :
Sprocs Referred	:
**********************************************************************************************/
/*MODIFICATIONS HISTORY IN CHRONOLOGICAL ORDER, WITH THE LATEST CHANGE BEING AT THE TOP.*/
/********************************************************************************************
MODIFIED BY      : 	Vic
MODIFICATIONS    :	Added (@ExtException1 and  @ExtException2) - non-deletable extensions.
					Temp modification / urgency. For generic purposes,
					should be further modified to NonDeletableFileMasks (list, ":" delimited)
DATE             :	Apr 2006
LABEL			 :  (060425)

MODIFIED BY      : 	Vlad
MODIFICATIONS    :	Changed name from aspr_DFSC_DelOldFiles to aspr_LS_DelOldFiles_ExtExceptions
DATE             :	April 2006
**********************************************************************************************/


/***********************************************************************************************
DESCRIPTION
**********************************************************************************************/

AS BEGIN
SET NOCOUNT ON

	DECLARE @proc_name sysname    			--used for unified calling of ADM_WRITE_SQL_ERR_LOG
	SELECT @proc_name = name FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int			--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @logmsg nvarchar(255)			-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------
	DECLARE @hr_obj int				-- var for OAGetErrorInfo

	DECLARE @hr int
	DECLARE @fso int
	DECLARE @folder int
	DECLARE @file int

	SET @logmsg = 'Execution start of ' + @proc_name
	DECLARE @params_info varchar(1000)
	SET @params_info = '@Path = nvarchar(255) = ' + isNull('''' + @Path + '''', 'NULL') + CHAR(10)
						+ '@DaysOld int = ' + isNull(convert(varchar(100), @DaysOld), 'NULL')

	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @SystemName_Log,
								@AgentName = @proc_name,
								@Statement = '/**** Input parameters ****/',
								@RecordCount = @rcnt,
								@LogDesc = 	@params_info,
								@UserId = NULL,
								@IsLogOnly = 1


/*
	SELECT 	@hr_obj = @fso,
			@stmnt_lastexec = "EXEC @hr = sp_OAMethod @fso,'GetFolder', @folder OUT,
@Path"
    EXEC @hr = sp_OAMethod @fso,'GetFolder', @folder OUT, @Path
    IF (@hr <> 0) GOTO OAErr
*/
	CREATE TABLE #DFSC_DelOldFiles_dirtree (
		subdirectory nvarchar(260),
		depth	int,
		is_file	bit
	)

	IF OBJECT_ID('tempdb..#DFSC_DelOldFiles_filedetails', 'U') > 0
		DROP TABLE #DFSC_DelOldFiles_filedetails
	CREATE TABLE #DFSC_DelOldFiles_filedetails
	(
	    AlternateName varchar(32),
	    Size int,
	    CreationDate int,
	    CreationTime int,
	    LastWrittenDate int,
	    LastWrittenTime int,
	    LastAccessedDate int,
	    LastAccessedTime int,
	    Attributes int

	)

	DECLARE @do_drop_dfsc_files bit
	SET @do_drop_dfsc_files = 0
	IF isNull(OBJECT_ID('tempdb..#DrivesFreeSpaceControl_files', 'U'),0) = 0 BEGIN
		SET @do_drop_dfsc_files = 1
		SELECT 	@stmnt_lastexec = "CREATE TABLE #DrivesFreeSpaceControl_files (	...."
		CREATE TABLE #DrivesFreeSpaceControl_files (
						Path nvarchar(1000),
						FileName nvarchar(255),
					    Size int,
					    CreationDate int,
					    CreationTime int,
					    LastWrittenDate int,
					    LastWrittenTime int,
					    LastAccessedDate int,
					    LastAccessedTime int,
					    Attributes int,
						Status	varchar(10),
						VBErrorInfo nvarchar(1000)
						PRIMARY KEY (Path, FileName)
					)
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
	END
	SELECT 	@stmnt_lastexec = "INSERT INTO #DFSC_DelOldFiles_dirtree (subdirectory, depth, is_file) ..."
	INSERT INTO #DFSC_DelOldFiles_dirtree (subdirectory, depth, is_file)
			EXEC master.dbo.xp_dirtree	@Path, 1, 1
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

	SELECT subdirectory FROM #DFSC_DelOldFiles_dirtree WHERE is_file = 1
		AND subdirectory NOT LIKE isNull('%'+@ExtException1,  subdirectory) --(060425)
		AND	subdirectory NOT LIKE isNull('%'+ @ExtException2, subdirectory) --(060425)

	DECLARE aspr_LS_DelOldFiles_ExtExceptions_dirtree_cur CURSOR
		FOR SELECT subdirectory FROM #DFSC_DelOldFiles_dirtree WHERE is_file = 1
		AND subdirectory NOT LIKE isNull('%'+@ExtException1,  subdirectory) --(060425)
		AND	subdirectory NOT LIKE isNull('%'+ @ExtException2, subdirectory) --(060425)
	DECLARE @file_name nvarchar(260), @file_path nvarchar(260)

	OPEN aspr_LS_DelOldFiles_ExtExceptions_dirtree_cur
	IF (right(@Path, 1) <> '\') SET @Path = @Path + '\'

	SELECT 	@stmnt_lastexec = "EXEC @hr=sp_OACreate 'Scripting.FileSystemObject', @hr_obj OUT"
	EXEC @hr=sp_OACreate 'Scripting.FileSystemObject', @hr_obj OUT
	IF (@hr <> 0) GOTO OAErr
	SELECT 	@fso = @hr_obj
	WHILE (1=1) BEGIN
		FETCH NEXT FROM aspr_LS_DelOldFiles_ExtExceptions_dirtree_cur INTO @file_name
		IF (@@FETCH_STATUS <> 0) BREAK
		SET @file_path = @Path + @file_name

		SELECT 	@stmnt_lastexec = "INSERT INTO #DFSC_DelOldFiles_filedetails ..."
		INSERT INTO #DFSC_DelOldFiles_filedetails
		EXEC master..xp_getfiledetails @file_path
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO ErrCloseCur

		SELECT 	@stmnt_lastexec = "INSERT INTO #DrivesFreeSpaceControl_files ..."
		INSERT INTO #DrivesFreeSpaceControl_files
			(Path, FileName, Size,
				CreationDate, CreationTime,
				LastWrittenDate, LastWrittenTime,
				LastAccessedDate, LastAccessedTime,
				Attributes)
		SELECT @Path, @file_name,
				Size,
				CreationDate, CreationTime,
				LastWrittenDate, LastWrittenTime,
				LastAccessedDate, LastAccessedTime,
				Attributes
		FROM #DFSC_DelOldFiles_filedetails
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO ErrCloseCur

		IF EXISTS(SELECT * FROM #DFSC_DelOldFiles_filedetails
				WHERE convert (datetime, cast(LastWrittenDate as varchar(20)), 112)
						< dateAdd(dd, @DaysOld * -1, getDate())
					) BEGIN

			SELECT 	@hr_obj = @fso,
					@stmnt_lastexec = "EXEC @hr = sp_OAMethod @fso,'DeleteFile', NULL, @Path"
		    EXEC @hr = sp_OAMethod @fso,'DeleteFile', NULL, @file_path
		    IF (@hr = 0) BEGIN
				UPDATE #DrivesFreeSpaceControl_files
						SET Status = 'Deleted'
						WHERE Path = @Path AND FileName = @file_name
			END ELSE
				UPDATE #DrivesFreeSpaceControl_files
						SET Status = 'Error',
							VBErrorInfo = dbo.OAGetErrorInfo (@hr_obj, @hr)
						WHERE Path = @Path AND FileName = @file_name
		END ELSE BEGIN
			UPDATE #DrivesFreeSpaceControl_files SET Status = 'Skipped'
					WHERE Path = @Path AND FileName = @file_name
		END --IF EXISTS(SELECT * FROM #DFSC_DelOldFiles_filedetails
		DELETE #DFSC_DelOldFiles_filedetails
	END --aspr_LS_DelOldFiles_ExtExceptions_dirtree_cur
	CLOSE aspr_LS_DelOldFiles_ExtExceptions_dirtree_cur
	DEALLOCATE aspr_LS_DelOldFiles_ExtExceptions_dirtree_cur
	--		EXEC master.dbo.xp_getfiledetails 'D:\tmp\rttt.htm'

	DECLARE @files_info	nvarchar(4000)
	SELECT 	@stmnt_lastexec = "EXEC @err = aspr_LS_FilesInfo2Str @Path, @files_info OUT"
	--EXEC aspr_LS_FilesInfo2Str @Path = @Path, @Info = @files_info OUT
	EXEC @err = aspr_LS_FilesInfo2Str @Path, @files_info OUT
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

	DECLARE @sbj nvarchar(260)
	SET @sbj = '/**** Files Processing Results for ' + @Path + '****/'
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @SystemName_Log,
							@AgentName = @proc_name,
							@Statement = @sbj,
							@RecordCount = @rcnt,
							@LogDesc = 	@files_info,
							@UserId = NULL,
							@IsLogOnly = 1

	SET @sbj = 'Files Processing Results for ' + @Path
	DECLARE @ewlevel int
	SET @ewlevel = 1
	IF (EXISTS (SELECT * FROM #DrivesFreeSpaceControl_files
		WHERE Path = @Path AND Status <> 'Skipped')) SET @ewlevel = 2

	SELECT 	@stmnt_lastexec = "EXEC @err = aspr_LS_AddEmail 	@Subject = @sbj, ..."
	EXEC @err = aspr_LS_AddEmail 	@Subject = @sbj,
					@WarnLevel = @ewlevel,
					@Body = @files_info
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err


	IF EXISTS (SELECT * FROM #DrivesFreeSpaceControl_files
						WHERE Status = 'Error'
			) BEGIN
		SELECT 	@stmnt_lastexec = "EXEC @err = aspr_LS_AddEmail 	@Subject = 'There were errors upon some file delete attempts',..."
		EXEC @err = aspr_LS_AddEmail 	@Subject = 'There were errors upon some file delete attempts',
							@WarnLevel = 2,
							@Body = NULL
		SELECT @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
	END

	IF (@do_drop_dfsc_files = 1) BEGIN
		SELECT * FROM #DrivesFreeSpaceControl_files
		DROP TABLE #DrivesFreeSpaceControl_files
	END

	RETURN 0
ErrCloseCur:
	CLOSE aspr_LS_DelOldFiles_ExtExceptions_dirtree_cur
	DEALLOCATE aspr_LS_DelOldFiles_ExtExceptions_dirtree_cur
	Goto Err
OAErr:
	CLOSE aspr_LS_DelOldFiles_ExtExceptions_dirtree_cur
	DEALLOCATE aspr_LS_DelOldFiles_ExtExceptions_dirtree_cur
	SET @logmsg = isNull(@logmsg, '') + dbo.OAGetErrorInfo (@hr_obj, @hr)
	SELECT @logmsg
	SET @err = @hr
Err:
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @SystemName_Log,
							@AgentName = @proc_name,
							@Statement = @stmnt_lastexec,
							@ErrCode = @err,
							@RecordCount = @rcnt,
							@LogDesc = @logmsg,
							@EMNotify = NULL,
							@UserId = NULL

	IF (@do_drop_dfsc_files = 1) BEGIN
		SELECT * FROM #DrivesFreeSpaceControl_files
		DROP TABLE #DrivesFreeSpaceControl_files
	END

	RETURN @err
END


GO

