IF OBJECT_ID('atbl_LogGrowSimulation_DummyTrans', 'U') > 0 
		DROP TABLE atbl_LogGrowSimulation_DummyTrans
CREATE TABLE atbl_LogGrowSimulation_DummyTrans
  (ID int identity, DummyColumn char (8000) not null)
GO



DROP PROC  aspr_LogGrowSimulation
GO
CREATE PROC  aspr_LogGrowSimulation @MaxMinutes INT, @NewSizeMB INT
--EXEC aspr_LogGrowSimulation 1, 10
AS BEGIN 
	SET NOCOUNT ON
	DECLARE @logical_log_name sysname, @log_drive char(1)
	EXEC aspr_GetLogicalLogNameAndDrive @logical_log_name OUT, @log_drive OUT
	
-- Setup / initialize
	DECLARE @OriginalSize int
	SELECT @OriginalSize = size      -- in 8K pages
	  FROM sysfiles
	  WHERE name = @logical_log_name
	SELECT 'Original Size of ' + db_name() + ' LOG is ' +
	     CONVERT(VARCHAR(30),@OriginalSize) + ' 8K pages or ' +
	     CONVERT(VARCHAR(30),(@OriginalSize*8/1024)) + 'MB'
--  FROM sysfiles
--  WHERE name = @logical_log_name

-- Wrap log and truncate it.
	DECLARE @StartTime DATETIME
	SELECT @StartTime = GETDATE()
	WHILE @MaxMinutes > DATEDIFF (mi, @StartTime, GETDATE())      -- time has not expired
	     AND (@OriginalSize * 8 /1024) < @NewSizeMB     -- The value passed in for new size is smaller than the current size.
	BEGIN -- Outer loop.
			INSERT atbl_LogGrowSimulation_DummyTrans (DummyColumn)
				VALUES ('Fill Log')     -- Because it is a char field it inserts 8000 bytes.
			DELETE atbl_LogGrowSimulation_DummyTrans
			SELECT @OriginalSize = size      -- in 8K pages
				FROM sysfiles
				WHERE name = @logical_log_name
	  END
	SELECT 'Final Size of ' + db_name() + ' LOG is ' +
		     CONVERT(VARCHAR(30),size) + ' 8K pages or ' +
		     CONVERT(VARCHAR(30),(size*8/1024)) + 'MB'
		FROM sysfiles 
		WHERE name = @logical_log_name
END
GO

