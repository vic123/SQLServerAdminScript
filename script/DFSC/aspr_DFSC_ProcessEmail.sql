DROP PROCEDURE aspr_DFSC_ProcessEmail 
go
CREATE PROCEDURE aspr_DFSC_ProcessEmail @EMTo nvarchar(255) = NULL, @EMCCList nvarchar(1000) = NULL 
AS BEGIN
	IF (@EMTo IS NULL AND @EMCCList IS NULL) RETURN
	IF NOT EXISTS (SELECT * FROM #DrivesFreeSpaceControl_email 
				WHERE WarnLevel > 1)	RETURN 0 --we are not spammers

	DECLARE @msg nvarchar(4000)
	SELECT @msg = isNull(@msg + CHAR(10) + CHAR(10) + '********************' + CHAR(10) + CHAR(10), CHAR(10))
				+ 'WarnLevel: ' + CASE WarnLevel
									WHEN 1 THEN 'INFO' 
									WHEN 2 THEN 'NOTIFICATION' 
									WHEN 3 THEN 'ALERT' 
									WHEN 4 THEN 'WARNING' 
									WHEN 5 THEN 'ERROR' 
									ELSE convert(varchar, WarnLevel)
								END + CHAR(10) 
				+ 'Subject: ' + isNull(Subject, 'NULL') + CHAR(10) 
				+ 'Details: ' + isNull(Body, 'NULL')
		FROM #DrivesFreeSpaceControl_email
		ORDER BY WarnLevel DESC, ID
	
	DECLARE @sbj nvarchar(4000), @tmp int
	SELECT @tmp = WarnLevel, 
			@sbj = isNull(@sbj + ',', 'DM TranLog & Drives (aspr_DrivesFreeSpaceControl): ')
					 + CASE WarnLevel
							WHEN 1 THEN 'INFO' 
							WHEN 2 THEN 'NOTIFICATION' 
							WHEN 3 THEN 'ALERT' 
							WHEN 4 THEN 'WARNING' 
							WHEN 5 THEN 'ERROR' 
						END 
		FROM #DrivesFreeSpaceControl_email
		WHERE WarnLevel > 1
		GROUP BY WarnLevel
		ORDER BY WarnLevel

	DECLARE @err int
	EXEC @err = sp_EmailAlert2 @ModuleName = @sbj, @Msg = @msg, @CcList =  @EMCCList
	RETURN @err
END
GO

