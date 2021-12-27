SET QUOTED_IDENTIFIER OFF
GO

DROP PROCEDURE aspr_DFSC_SetDrivesCapacityMB
GO
--todo. Full backup after log trunking?
CREATE PROCEDURE aspr_DFSC_SetDrivesCapacityMB
AS BEGIN

	DECLARE @proc_name sysname					--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	SELECT @proc_name = name FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int					--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @logmsg nvarchar(255)				-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------
	DECLARE @hr_obj int							-- var for OAGetErrorInfo

	SELECT 	@stmnt_lastexec = "CREATE TABLE #DFSC_SetDrivesCapacityMB_drivesCapacity (	drive char(1) PRIMARY KEY,	CapacityMB bigint NOT NULL)"
	CREATE TABLE #DFSC_SetDrivesCapacityMB_drivesCapacity (	drive char(1) PRIMARY KEY,	CapacityMB bigint NOT NULL)
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	DECLARE @all_drives_list varchar(100)
	SELECT @all_drives_list = isNull(@all_drives_list + ',', '') + drive
		FROM #DrivesFreeSpaceControl_drives ORDER BY drive

	SET @logmsg = @all_drives_list
	SELECT 	@stmnt_lastexec = "INSERT #DFSC_SetDrivesCapacityMB_drivesCapacity (drive, CapacityMB) EXEC @err = aspr_DrivesCapacityMB_ListParam @all_drives_list"
	INSERT #DFSC_SetDrivesCapacityMB_drivesCapacity (drive, CapacityMB) EXEC @err = aspr_DrivesCapacityMB_ListParam @all_drives_list
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 


	SELECT 	@stmnt_lastexec = "UPDATE drives SET CapacityMB = dC.CapacityMB..."
	UPDATE drives SET CapacityMB = dC.CapacityMB
		FROM #DrivesFreeSpaceControl_drives drives 
			JOIN #DFSC_SetDrivesCapacityMB_drivesCapacity dC ON drives.Drive = dC.Drive
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
