


SET QUOTED_IDENTIFIER OFF
GO

DROP PROCEDURE aspr_DFSC_SetDrivesFreeSpaceMB
GO
--todo. Full backup after log trunking?
CREATE PROCEDURE aspr_DFSC_SetDrivesFreeSpaceMB
AS BEGIN

	DECLARE @proc_name sysname					--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	SELECT @proc_name = name FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int					--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @logmsg nvarchar(255)				-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------
	DECLARE @hr_obj int							-- var for OAGetErrorInfo

	SELECT 	@stmnt_lastexec = "CREATE TABLE #DrivesFreeSpaceControl_drivesFreeSpace (	Drive char(1) PRIMARY KEY,	FreeSpaceMB int NOT NULL)"
	CREATE TABLE #DrivesFreeSpaceControl_drivesFreeSpace (	drive char(1) PRIMARY KEY,	FreeSpaceMB bigint NOT NULL)
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 
	SELECT 	@stmnt_lastexec = "INSERT #DrivesFreeSpaceControl_drivesFreeSpace (drive,FreeSpaceMB) EXEC @err = master.dbo.xp_fixeddrives"
	INSERT #DrivesFreeSpaceControl_drivesFreeSpace (drive, FreeSpaceMB) EXEC @err = master.dbo.xp_fixeddrives
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	SELECT 	@stmnt_lastexec = "UPDATE drives SET FreeSpaceMB = dFS.FreeSpaceMB..."
	UPDATE drives SET FreeSpaceMB = dFS.FreeSpaceMB
		FROM #DrivesFreeSpaceControl_drives drives 
			JOIN #DrivesFreeSpaceControl_drivesFreeSpace dFS ON drives.Drive = dFS.Drive
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	SELECT 	@stmnt_lastexec = "INSERT INTO #DrivesFreeSpaceControl_drives (Drive, FreeSpaceMB)..."
	INSERT INTO #DrivesFreeSpaceControl_drives (Drive, FreeSpaceMB)
		SELECT Drive, FreeSpaceMB FROM #DrivesFreeSpaceControl_drivesFreeSpace dFS
		WHERE NOT EXISTS(SELECT * 
							FROM #DrivesFreeSpaceControl_drives drives 
							WHERE drives.Drive = dFS.Drive
						)
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	RETURN 0
Err:
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'DMDBA', 
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
