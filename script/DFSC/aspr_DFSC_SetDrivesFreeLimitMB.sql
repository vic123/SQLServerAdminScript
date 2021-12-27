SET QUOTED_IDENTIFIER OFF
GO

DROP PROCEDURE aspr_DFSC_SetDrivesFreeLimitMB
GO
--todo. Full backup after log trunking?
CREATE PROCEDURE aspr_DFSC_SetDrivesFreeLimitMB @DrivesFreeLimits varchar(2000), @DefFreeLimitPercent smallint
AS BEGIN

	DECLARE @proc_name sysname					--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	SELECT @proc_name = name FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int					--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @logmsg nvarchar(255)				-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------
	DECLARE @hr_obj int							-- var for OAGetErrorInfo

	SELECT 	@stmnt_lastexec = "SELECT str1 drive, str2 Limit INTO #DFSC_SetDrivesFreeLimitMB_driveLimits"
	SELECT str1 drive, str2 Limit INTO #DFSC_SetDrivesFreeLimitMB_driveLimits
	FROM aspr_Iter2CharListToTable(@DrivesFreeLimits, '::') 
	ORDER BY str1
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	SELECT 	@stmnt_lastexec = "UPDATE drives SET FreeLimitMB = CASE..."
	UPDATE drives SET FreeLimitMB = CASE 
				WHEN right(Limit, 1) = '%' THEN convert(smallint, left(Limit, len(Limit) - 1)) * CapacityMB / 100
				WHEN Limit IS NULL THEN @DefFreeLimitPercent * CapacityMB / 100
				ELSE convert(bigint, Limit)
			END
		FROM #DrivesFreeSpaceControl_drives drives
			LEFT JOIN #DFSC_SetDrivesFreeLimitMB_driveLimits dL ON drives.Drive = dL.Drive
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	SELECT 	@stmnt_lastexec = "INSERT INTO #DrivesFreeSpaceControl_drives drives (drive, FreeLimitMB)..."
	INSERT INTO #DrivesFreeSpaceControl_drives (drive, FreeLimitMB)
		SELECT Drive, 	CASE
							WHEN (right(Limit, 1) = '%') THEN NULL
							ELSE convert(bigint, Limit)
						END FreeLimitMB
			FROM #DFSC_SetDrivesFreeLimitMB_driveLimits dL
			WHERE NOT EXISTS (SELECT * FROM #DrivesFreeSpaceControl_drives drives 
								WHERE dL.Drive = drives.Drive
							)
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 
	IF (@rcnt <> 0) EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'DMDBA', 
									@AgentName = @proc_name,
									@Statement = @stmnt_lastexec,
									@RecordCount = @rcnt,
									@LogDesc = @logmsg,
									@UserId = NULL, 
									@IsWarnOnly = 1
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



