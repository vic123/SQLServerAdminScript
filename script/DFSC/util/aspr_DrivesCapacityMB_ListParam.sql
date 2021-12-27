
SET QUOTED_IDENTIFIER OFF
GO
DROP PROCEDURE aspr_DrivesCapacityMB_ListParam
GO
CREATE PROCEDURE aspr_DrivesCapacityMB_ListParam @DrivesList varchar(500), @Delimiter nvarchar(10) = N','
AS BEGIN 
/*
   Displays the free space,free space percentage 
   plus total drive size for a server
*/
SET NOCOUNT ON



	DECLARE @proc_name sysname					--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	SELECT @proc_name = name FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int					--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @logmsg nvarchar(255)				-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------
	DECLARE @hr_obj int							-- var for OAGetErrorInfo


	DECLARE @hr int
	DECLARE @fso int
	DECLARE @drive char(1)
	DECLARE @odrive int
	DECLARE @TotalSize varchar(20)
	DECLARE @MB bigint ; SET @MB = 1048576

	SELECT 	@stmnt_lastexec = "SELECT str drive, convert(bigint, 0) TotalSize	INTO #DrivesCapacityMB_drives..."
	SELECT str drive, convert(bigint, 0) TotalSize	INTO #DrivesCapacityMB_drives 
		FROM aspr_IterCharListToTable(@DrivesList, @Delimiter) 
		ORDER BY str
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

/*
	CREATE TABLE #drives (drive char(1) PRIMARY KEY,
	                      FreeSpace int NULL,
	                      TotalSize int NULL)

	
	SELECT 	@stmnt_lastexec = "INSERT #DrivesCapacityMB_drives (drive,FreeSpace)..."
	INSERT #DrivesCapacityMB_drives (drive,FreeSpace) 
	EXEC @err = master.dbo.xp_fixeddrives
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 
*/		
	SELECT 	@stmnt_lastexec = "EXEC @hr=sp_OACreate 'Scripting.FileSystemObject', @hr_obj OUT"
	EXEC @hr=sp_OACreate 'Scripting.FileSystemObject', @hr_obj OUT
	IF (@hr <> 0) GOTO OAErr
	SELECT 	@fso = @hr_obj

	DECLARE DrivesCapacityMB_cur CURSOR LOCAL FAST_FORWARD
	FOR SELECT Drive from #DrivesCapacityMB_drives
	ORDER by Drive

	OPEN DrivesCapacityMB_cur
	
	FETCH NEXT FROM DrivesCapacityMB_cur INTO @drive
	
	WHILE @@FETCH_STATUS=0
	BEGIN

		SELECT 	@hr_obj = @fso,
				@stmnt_lastexec = "EXEC @hr = sp_OAMethod @fso,'GetDrive', @odrive OUT, @drive"
        EXEC @hr = sp_OAMethod @fso,'GetDrive', @odrive OUT, @drive
        IF (@hr <> 0) GOTO OAErrCloseCur

		SELECT 	@hr_obj = @odrive,
				@stmnt_lastexec = "EXEC @hr = sp_OAGetProperty @odrive,'TotalSize', @TotalSize OUT"
        EXEC @hr = sp_OAGetProperty @odrive,'TotalSize', @TotalSize OUT
        IF (@hr <> 0) GOTO OAErrCloseCur
                        
        UPDATE #DrivesCapacityMB_drives
        SET TotalSize=@TotalSize/@MB
        WHERE Drive=@drive
        
        FETCH NEXT FROM DrivesCapacityMB_cur INTO @drive
	END

	CLOSE DrivesCapacityMB_cur
	DEALLOCATE DrivesCapacityMB_cur

	SELECT 	@hr_obj = @fso,
			@stmnt_lastexec = "EXEC @hr=sp_OADestroy @fso"
	EXEC @hr=sp_OADestroy @fso
    IF (@hr <> 0) GOTO OAErr


	SELECT drive,
--	       FreeSpace as 'Free(MB)',
	       TotalSize as CapacityMB
--	       CAST((FreeSpace/(TotalSize*1.0))*100.0 as int) as 'Free(%)'
		FROM #DrivesCapacityMB_drives
		ORDER BY drive

DROP TABLE #DrivesCapacityMB_drives

	RETURN 0
OAErrCloseCur:
	CLOSE DrivesCapacityMB_cur
	DEALLOCATE DrivesCapacityMB_cur
OAErr:
--	CLOSE GetDTSPkgInfo_Cur
--	DEALLOCATE GetDTSPkgInfo_Cur

	SET @logmsg = isNull(@logmsg, '') + dbo.OAGetErrorInfo (@hr_obj, @hr) 
	SET @err = @hr
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
go

SET QUOTED_IDENTIFIER ON
GO


--exec DrivesCapacityMB
--exec DrivesCapacityMB 'C,D,F'
--exec DrivesCapacityMB 'C::D::F', '::'


