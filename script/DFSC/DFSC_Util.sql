
DROP PROCEDURE aspr_DFSC_DrivesSpaceInfo2Str
GO
CREATE PROCEDURE aspr_DFSC_DrivesSpaceInfo2Str @Info varchar(1000) OUT
AS BEGIN
	SELECT @Info  = CHAR(10) + 'Drive' + CHAR(9) + 'FreeSpaceMB' + CHAR(9) + 'CapacityMB' + CHAR(9) + 'FreeLimitMB' + CHAR(10)
	SELECT @Info = @Info	+ isNull(Drive, 'NULL') + CHAR(9) 
							+ isNull(convert(varchar(100), FreeSpaceMB), 'NULL') + CHAR(9) + CHAR(9)
							+ isNull(convert(varchar(100), CapacityMB), 'NULL') + CHAR(9) + CHAR(9)
							+ isNull(convert(varchar(100), FreeLimitMB), 'NULL') + CHAR(10) 
		FROM #DrivesFreeSpaceControl_drives
	RETURN @@ERROR
END
GO

DROP PROCEDURE aspr_DFSC_LogSpaceInfo2Str
GO
CREATE PROCEDURE aspr_DFSC_LogSpaceInfo2Str @Info varchar(1000) OUT
AS BEGIN
	SELECT @Info  = CHAR(10) + 'DBName' + CHAR(9) + 'LogSizeMB' + CHAR(9) + 'LogUsedPercent' + CHAR(9) + 'LogFreeMB' + CHAR(9) + 'ShrinkThreshold' + CHAR(10) 
	SELECT @Info = @Info	+ isNull(DBName, 'NULL') + CHAR(9) 
							+ isNull(convert(varchar(100), LogSizeMB), 'NULL') + CHAR(9) + CHAR(9)
							+ isNull(convert(varchar(100), LogUsedPercent), 'NULL') + CHAR(9) + CHAR(9)
							+ isNull(convert(varchar(100), LogSizeMB - LogSizeMB*LogUsedPercent/100), 'NULL') + CHAR(9) + CHAR(9)
							+ isNull(convert(varchar(100), ShrinkThreshold), 'NULL') + CHAR(10) 
		FROM #DFSC_ShrinkLog_logspace
		WHERE ShrinkThreshold IS NOT NULL	--051222
		ORDER BY DBName
--		WHERE DBName = db_name()
	RETURN @@ERROR
END
GO

DROP PROCEDURE aspr_DFSC_FilesInfo2Str 
GO
CREATE PROCEDURE aspr_DFSC_FilesInfo2Str @Path nvarchar(260), @Info varchar(1000) OUT
AS BEGIN
	SELECT @Info  = CHAR(10) + 'Path' + CHAR(9) + 'FileName' + CHAR(9) + 'Size' + CHAR(9) 
							+ 'LWrDate' + CHAR(9) + 'Attributes' + CHAR(9) 
							+ 'Status' + CHAR(10)
	SELECT @Info = @Info	+ isNull(Path, 'NULL') + CHAR(9) 
							+ isNull(FileName, 'NULL') + CHAR(9) 
							+ isNull(convert(varchar(100), Size), 'NULL') + CHAR(9) 
							+ isNull(convert(varchar(100), DateLastModified), 'NULL') + CHAR(9) 
							+ isNull(convert(varchar(100), Attributes), 'NULL') + CHAR(9) 
							+ isNull(Status, 'NULL') + CHAR(10) 
		FROM #DrivesFreeSpaceControl_files
		WHERE Path = @Path
	RETURN @@ERROR
END
GO



DROP PROCEDURE aspr_DFSC_AddEmail 
GO
CREATE PROCEDURE aspr_DFSC_AddEmail 	@Subject varchar(200), 
								@WarnLevel smallint, 
								@Body varchar(1000)
AS BEGIN 
	IF isNull(OBJECT_ID('tempdb..#DrivesFreeSpaceControl_email', 'U'),0) <> 0 BEGIN
		INSERT INTO #DrivesFreeSpaceControl_email (Subject, WarnLevel, Body)
		VALUES (@Subject, @WarnLevel, @Body)
		RETURN @@ERROR
	END ELSE IF (@WarnLevel > 1) BEGIN --temp solution on the base of hardcoded CCList in sp_EmailAlert2
		DECLARE @err int
		EXEC @err = sp_EmailAlert2 @ModuleName = 'RCTSDM TranLog & Drives (aspr_DrivesFreeSpaceControl): WarnLevel > 1', 
					@Msg = @Body
	END
END
GO

