SET QUOTED_IDENTIFIER OFF
GO

DROP PROCEDURE aspr_DrivesFreeSpaceControl 	
GO
--todo. Full backup after log trunking?
--DFSC_SetDrivesCapacityMB -> DFSC_UpdateDrivesCapacityMB
CREATE PROCEDURE aspr_DrivesFreeSpaceControl
					--minimal percent of free space for any drive.   
					--@DrivesFreeLimits list overrides this parameter
											@DefFreeLimitPercent int = 10, 
					--DriveLetter::[DecimalNumber[%]][::DriveLetter::[DecimalNumber[%]]]
					--When DecimalNumber is not followed by % it is interpreted in MBs
					--P.S. :: is delimiter for 'paired' list. Both for fields and rows.
											@DrivesFreeLimits varchar(2000) = NULL, 
					--default maximum size of log of any DB, before it comes under attention.
					--if log size is above, then email and, 
					--depending on other parameters (see 2 below), 
					--shrink attempts are performed
					--@DBLogsShrinkThresholdsMB list overrides this parameter
					--NULL value allows any log size
					--IMPORTANT: value of 0 (zero) destroys logs with BACKUP LOG WITH TRUNCATE_ONLY
					--			statement before shrinking
--(051205)											@LogTrunkThresholdMB bigint = NULL, 
											@DefLogShrinkThresholdMB bigint = NULL,
					--DBName::[DecimalNumber][::DriveLetter::[DecimalNumber]] 
					--DecimalNumber is interpreted in MBs
					--IMPORTANT: When DecimalNumber is 0, 
					--		log is being destroyed by BACKUP LOG WITH TRUNCATE_ONLY
					--		(do not apply it for databases with log recovery model)
					--When DecimalNumber is ommited - works @DefLogShrinkThresholdMB 
											@DBLogsShrinkThresholdsMB varchar(2000) = NULL, 
					--an attempt of log shrinking will be done 
					--only if drive where it resides is below minimum free space
					--(@DefFreeLimitPercent overriden by @Dirs4FileDel)
											@ShrinkLogOnLowSpaceOnly bit = 1,
					--no log shrinking is done, no matter if its drive is below 
					--minimum free space or not
											@LogNotifyOnly bit = 0,
					--list of directories (full path) where files older than some days should be deleted
					--Path::[DecimalNumberD][::Path::[DecimalNumberD]]
					--When DecimalNumberD is missing, then files are "immortal" - nothing will 
					--	be deleted, but an informational "dir" output will be included in email 
					--D is an important at the end of the number of days that file would be untouchable
					--currntly only right shift is performed (cutting of right most symbol)
					--but it can be extended to [HDMY] (hour, day, month, year) variants
											@Dirs4FileDel nvarchar(4000) = NULL,
					--Directories from @Dirs4FileDel list will be processed (old files will be deleted)
					--ONLY if free space on the directory drive (left character of path) is below 
					--minimum free space (@DefFreeLimitPercent overriden by @Dirs4FileDel)
					--Directory paths may have or don't have ending back slash (it will be appended by script when necessary)
											@DelFilesOnLowSpaceOnly bit = 1,
					--alert/warning/error emails recipient
											@EMTo nvarchar(255) = NULL, 
					--alert/warning/error emails CC list
											@EMCCList nvarchar(1000) = NULL 

/*
Sample simple calls:
1) If transaction log have grown above 1000MB, then
	a) try to shrink it
	b) send email notification 
exec aspr_DrivesFreeSpaceControl @DefFreeLimitPercent = 0,
							@DefLogShrinkThresholdMB = 1000, 
							@ShrinkLogOnLowSpaceOnly = 0,
							@LogNotifyOnly = 0,
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 
2) If transaction log have grown above 1000MB, then send email notification only
(no shrinking)
exec aspr_DrivesFreeSpaceControl @DefFreeLimitPercent = 0,
							@DefLogShrinkThresholdMB = 1000, 
							@LogNotifyOnly = 1,
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 
3) If free space on ANY drive is below 5% of total drive capacity, then notify by email
exec aspr_DrivesFreeSpaceControl 		@DefFreeLimitPercent = 5, 
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 
4) If 
	a) free space on drive c: is below 100MB
	b) free space on drive d: is below 10% of total drive capacity
	c) free space on drive e: is below 2% of total drive capacity
	d) free space on ANY OTHER than mentioned above drive is below 5% of total drive capacity,
then notify by email

exec aspr_DrivesFreeSpaceControl 		@DefFreeLimitPercent = 5, 
									@DrivesFreeLimits = 'C::100::D::10%::E::2%',
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 

5) If transaction log have grown above 1000MB then notify by email,
	and if log resides on drive c: and free space on drive c: is below 100MB 
	then try to shrink log

exec aspr_DrivesFreeSpaceControl @DefFreeLimitPercent = 0,
							@DrivesFreeLimits = 'C::100',
							@DefLogShrinkThresholdMB = 1000, 
							@ShrinkLogOnLowSpaceOnly = 1,
							@LogNotifyOnly = 0,
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 

6) Delete all files 
	a) from c:\DFSC_Test that are older than 7 days
	b) from d:\tmp that are older than 15 days

exec aspr_DrivesFreeSpaceControl 		@DefFreeLimitPercent = 0, 
									@Dirs4FileDel = 'c:\DFSC_Test::5D::d:\tmp::15D',
									@DefLogShrinkThresholdMB = NULL, 
									@DelFilesOnLowSpaceOnly = 0
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 

6) If free space on drive c: is below 100MB 
	then notify by email
	and delete all files from c:\DFSC_Test that are older than 7 days 

exec aspr_DrivesFreeSpaceControl 		@DefFreeLimitPercent = 0, 
									@DrivesFreeLimits = 'C::100',
									@Dirs4FileDel = 'c:\DFSC_Test::7D',
									@DelFilesOnLowSpaceOnly = 1
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 

Sample real-life calls:
1) 
LOG - EM NOTIGY + allways SHRINK on threshold of 1000MB
DRIVE C: only EMNOTIFY if free space < 500MB
Drive D:  if free space < 700MB then EM Notify + delete files older than 7 days from a folder D:\tmp
Drive F : SAME as D.

exec aspr_DrivesFreeSpaceControl 	@DefFreeLimitPercent = 0, 
									@DrivesFreeLimits = 'C::500::D::700::F::700',
									@DefLogShrinkThresholdMB = 1000, 
									@ShrinkLogOnLowSpaceOnly = 0,
									@LogNotifyOnly = 0,
									@Dirs4FileDel = 'd:\tmp::7D::f:\tmp::7D',
									@DelFilesOnLowSpaceOnly = 1
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 

2)
LOG - EM NOTIGY + DO NOT   SHRINK on threshold. Just notify.
DRIVE C: only EMNOTIFY if free space < 500M.Just notify.
Drive D:  if free space < 700MB then EM Notify + delete files older than 7 days from a folder D:\tmp
Drive F :  SAME as D.

exec aspr_DrivesFreeSpaceControl 		@DefFreeLimitPercent = 0, 
									@DrivesFreeLimits = 'C::500::D::700::F::700',
									@DefLogShrinkThresholdMB = 1000, 
									@LogNotifyOnly = 1,
									@Dirs4FileDel = 'd:\tmp::7D::f:\tmp::7D',
									@DelFilesOnLowSpaceOnly = 1
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 

3)
LOG - EM NOTIGY + DO NOT   SHRINK on threshold. Just notify.
DRIVE C: only EMNOTIFY if free space < 500M.Just notify.
Drive D:  if free space < 700MB then EM Notify + DO NOT delete files from a d:\tmp. Just notify.
Drive F :  if free space < 700MB then EM Notify + delete files from f:\tmp

exec aspr_DrivesFreeSpaceControl 		@DefFreeLimitPercent = 0, 
									@DrivesFreeLimits = 'C::500::D::700::F::700',
									@DefLogShrinkThresholdMB = 1000, 
									@LogNotifyOnly = 1,
									@Dirs4FileDel = 'f:\tmp::7D',
									@DelFilesOnLowSpaceOnly = 1
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 

*/
											
--TEST_SCRIPTS:
/*	
--Preconditions (manual operations involved, execute statements one by one in this comment block)
--1) Create test database 
--DROP DATABASE DFSC_Test
CREATE DATABASE DFSC_Test
	ON ( NAME = DFSC_Test_dat,  FILENAME = 'c:\DFSC_Test.mdf')
	LOG ON ( NAME = 'DFSC_Test_log', FILENAME = 'c:\DFSC_Test.ldf')

CREATE DATABASE DFSC_Test1
	ON 
	( NAME = DFSC_Test1_dat,
	   FILENAME = 'c:\DFSC_Test1.mdf')
	LOG ON
	( NAME = 'DFSC_Test_log',
	   FILENAME = 'c:\DFSC_Test1.ldf')


CREATE DATABASE DFSC_Test2
	ON 
	( NAME = DFSC_Test2_dat,
	   FILENAME = 'd:\DFSC_Test2.mdf')
	LOG ON
	( NAME = 'DFSC_Test_log',
	   FILENAME = 'd:\DFSC_Test2.ldf')

CREATE DATABASE DFSC

USE DFSC
--generate DFSC_script.tmp.sql (do it manually)
USE DFSC_Test
--test\aspr_LogGrowSimulation, test\aspr_GetLogicalLogNameAndDrive 
--Backup db - we'll later use this backup in test scripts
--EXEC master.dbo.sp_dropdevice 'DFSC_Test_BKK', @delfile = 'delfile' 
EXEC master.dbo.sp_addumpdevice 'disk', 'DFSC_Test_BKK', 'c:\DFSC_Test.bkk'
BACKUP DATABASE DFSC_Test TO DFSC_Test_BKK

exec xp_cmdshell 'mkdir c:\DFSC_Test'
exec xp_cmdshell 'mkdir c:\DFSC_Test_Data'
exec xp_cmdshell 'mkdir d:\DFSC_Test'

--copy into c:\DFSC_Test_Data
--FileTouch.exe utility from test subdirectory
-- 1 file with size between 1 and 2 MB and rename it to OldFile
-- 1 file of arbitrary size and rename it to NewFile

DECLARE @dt datetime, @cmd varchar(8000)
SELECT @dt = getdate()
SELECT @dt = dateAdd(dd, -7, @dt)
SELECT @cmd = 'c:\DFSC_Test_Data\FileTouch.exe /D ' 
				+ cast(month(@dt) as varchar) 
				+ '-' + cast(day(@dt) as varchar) 
				+ '-' + cast(year(@dt) as varchar)
				+ ' c:\DFSC_Test_Data\OldFile*' 
SELECT @cmd
exec xp_cmdshell @cmd

DECLARE @dt datetime, @cmd varchar(8000)
SELECT @dt = getdate()
SELECT @dt = dateAdd(dd, -1, @dt)
SELECT @cmd = 'c:\DFSC_Test_Data\FileTouch.exe /D ' 
				+ cast(month(@dt) as varchar) 
				+ '-' + cast(day(@dt) as varchar) 
				+ '-' + cast(year(@dt) as varchar)
				+ ' c:\DFSC_Test_Data\NewFile*' 
SELECT @cmd
exec xp_cmdshell @cmd
*/

/* TEST_SCRIPT_1
1) If transaction log of have grown above 50MB, then
	a) try unsuccessfully to shrink it 
	b) send email notification 

USE DFSC

DROP DATABASE DFSC_Test

RESTORE DATABASE DFSC_Test FROM DFSC_Test_BKK

USE DFSC_Test

exec aspr_LogGrowSimulation 1, 55

USE DFSC


exec aspr_DrivesFreeSpaceControl @DefFreeLimitPercent = 0,
							@DefLogShrinkThresholdMB = NULL, 
							@DBLogsShrinkThresholdsMB ='DFSC_Test::50', 
							@ShrinkLogOnLowSpaceOnly = 0,
							@LogNotifyOnly = 0,
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 
--Expected results:
--WarnLevel: ALERT
--Subject: DFSC_Test_log was shrinked, but its new size is still above 50 MB


exec aspr_DrivesFreeSpaceControl @DefFreeLimitPercent = 0,
							@DefLogShrinkThresholdMB = 50, 
							@DBLogsShrinkThresholdsMB =NULL, 
							@ShrinkLogOnLowSpaceOnly = 0,
							@LogNotifyOnly = 0,
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 
--Expected results:
--WarnLevel: ALERT
--Subject: DFSC_Test_log was shrinked, but its new size is still above 50 MB


SELECT * FROM SQL_Err_Log
TEST_SCRIPT_1 end */

/* TEST_SCRIPT_2
1) If transaction log have grown above 50MB, then
	a) try successfully to shrink it 
	b) send email notification 
USE master

DROP DATABASE DFSC_Test

RESTORE DATABASE DFSC_Test FROM DFSC_Test_BKK

--RESTORE DATABASE DFSC_Test FROM DFSC_Test_log_BKK

USE DFSC_Test

exec aspr_LogGrowSimulation 1, 11

--could not achieve successfull shrinking after DB or LOG backup. 
--EXEC master.dbo.sp_addumpdevice 'disk', 'DFSC_Test_log_BKK', 'c:\DFSC_Test_log.bkk'
--BACKUP LOG DFSC_Test TO DFSC_Test_log_BKK
--BACKUP DATABASE DFSC_Test TO DFSC_Test_log_BKK - did not have same effect as BACKUP LOG with aspr_DrivesFreeSpaceControl "double run"
--EXEC master.dbo.sp_dropdevice 'DFSC_Test_log_BKK', @delfile = 'delfile' 
--BACKUP LOG DFSC_Test WITH TRUNCATE_ONLY

exec aspr_DrivesFreeSpaceControl @DefFreeLimitPercent = 0,
							@DefLogShrinkThresholdMB = 100, 
							@DBLogsShrinkThresholdsMB ='master::200::DFSC_Test::50', 
							@ShrinkLogOnLowSpaceOnly = 0,
							@LogNotifyOnly = 0,
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 
--Expected results:
--WarnLevel: NOTIFICATION
--Subject: DFSC_Test_log was shrinked, and its new size is below 5 MB

--SELECT * FROM SQL_ERR_LOG
TEST_SCRIPT_2 end */

/* TEST_SCRIPT_3
--If transaction log have grown above 10MB, then send email notification only
--(no shrinking)
USE master

DROP DATABASE DFSC_Test

RESTORE DATABASE DFSC_Test FROM DFSC_Test_BKK

USE DFSC_Test

exec aspr_LogGrowSimulation 1, 11

exec aspr_DrivesFreeSpaceControl @DefFreeLimitPercent = 0,
							@DefLogShrinkThresholdMB = 10, 
							@LogNotifyOnly = 1,
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 

--Expected results:
--WarnLevel: NOTIFICATION
--Subject: Log file has overgrown threshold size but was not shrinked
--Details: Either Because there are still 137MB above drive free space limit or @LogNotifyOnly parameter was set to 1
TEST_SCRIPT_3 end */

/* TEST_SCRIPT_4
--If free space on ANY drive is below 5% of total drive capacity, then notify by email
exec aspr_DrivesFreeSpaceControl 	@DefFreeLimitPercent = 5, 
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 
USE master

DROP DATABASE DFSC_Test

RESTORE DATABASE DFSC_Test FROM DFSC_Test_BKK

USE DFSC_Test

exec aspr_DrivesFreeSpaceControl 	@DefFreeLimitPercent = 5, 
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 
--Expected results:
--WarnLevel: WARNING
--Subject: Some drives are below free limit after (possible) log shrinking and/or outdated files deleting
TEST_SCRIPT_4 end */

/* TEST_SCRIPT_5
--If free space on drive c: is below xxMB then notify by email


USE master

DROP DATABASE DFSC_Test

RESTORE DATABASE DFSC_Test FROM DFSC_Test_BKK

USE DFSC_Test

CREATE TABLE #fixeddrives (	drive char(1) PRIMARY KEY,	FreeSpaceMB bigint NOT NULL)
INSERT #fixeddrives (drive, FreeSpaceMB) EXEC master.dbo.xp_fixeddrives
DECLARE @DrivesFreeLimits varchar(100)
SELECT @DrivesFreeLimits = 'C::' + cast(FreeSpaceMB + 1 as varchar)
FROM #fixeddrives WHERE drive = 'C'
SELECT @DrivesFreeLimits
exec aspr_DrivesFreeSpaceControl 	@DefFreeLimitPercent = 0, 
									@DrivesFreeLimits = @DrivesFreeLimits,
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 
DROP TABLE #fixeddrives
--Expected results:
--WarnLevel: WARNING
--Subject: Some drives are below free limit after (possible) log shrinking and/or outdated files deleting
TEST_SCRIPT_5 end */


/* TEST_SCRIPT_6
--Transaction log have grown above 10MB then notify by email,
--	Log resides on drive c:, but free space on drive c: is above xxMB 
--	therefore do not try to shrink log

USE master

DROP DATABASE DFSC_Test

RESTORE DATABASE DFSC_Test FROM DFSC_Test_BKK

USE DFSC_Test

exec aspr_LogGrowSimulation 1, 11
CREATE TABLE #fixeddrives (	drive char(1) PRIMARY KEY,	FreeSpaceMB bigint NOT NULL)
INSERT #fixeddrives (drive, FreeSpaceMB) EXEC master.dbo.xp_fixeddrives
DECLARE @DrivesFreeLimits varchar(100)
SELECT @DrivesFreeLimits = 'C::' + cast(FreeSpaceMB - 1 as varchar)
FROM #fixeddrives WHERE drive = 'C'
SELECT @DrivesFreeLimits
exec aspr_DrivesFreeSpaceControl 	@DefFreeLimitPercent = 0, 
									@DrivesFreeLimits = @DrivesFreeLimits,
									@DefLogShrinkThresholdMB = 10, 
									@ShrinkLogOnLowSpaceOnly = 1,
									@LogNotifyOnly = 0,
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 

DROP TABLE #fixeddrives

--Expected results:
--WarnLevel: NOTIFICATION
--Subject: Log file has overgrown threshold size but was not shrinked
--Details: Either Because there are still 1MB above drive free space limit or @LogNotifyOnly parameter was set to 1
--Check INFO messages below for details
TEST_SCRIPT_6 end */

/* TEST_SCRIPT_7
--Delete all files 
--	a) from c:\DFSC_Test that are older than 7 days
--	b) from d:\tmp that are older than 15 days

exec master.dbo.xp_cmdshell 'copy c:\DFSC_Test_Data\NewFile* c:\DFSC_Test'
exec master.dbo.xp_cmdshell 'copy c:\DFSC_Test_Data\NewFile* d:\DFSC_Test'
exec master.dbo.xp_cmdshell 'copy c:\DFSC_Test_Data\OldFile* c:\DFSC_Test'
exec master.dbo.xp_cmdshell 'copy c:\DFSC_Test_Data\OldFile* d:\DFSC_Test'

exec aspr_DrivesFreeSpaceControl 	@DefFreeLimitPercent = 0, 
									@Dirs4FileDel = 'c:\DFSC_Test::7D::d:\DFSC_Test::15D',
									@DefLogShrinkThresholdMB = NULL, 
									@DelFilesOnLowSpaceOnly = 0,
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 

--Expected results:
--WarnLevel: NOTIFICATION
--Subject: Files Processing Results for c:\DFSC_Test\
--Details: 
--Path	FileName	Size	LWrDate	Attributes	Status
--c:\DFSC_Test\	NewFile	36182	20051129	32	Skipped
--c:\DFSC_Test\	OldFile	25127	20051123	32	Deleted
--c:\DFSC_Test\	OldFile1	1309221	20051123	32	Deleted
--........
--WarnLevel: INFO
--Subject: Files Processing Results for d:\DFSC_Test\
--Details: 
--Path	FileName	Size	LWrDate	Attributes	Status
--d:\DFSC_Test\	NewFile	36182	20051129	32	Skipped
--d:\DFSC_Test\	OldFile	25127	20051123	32	Skipped
--d:\DFSC_Test\	OldFile1	1309221	20051123	32	Skipped


TEST_SCRIPT_7 end */

/* TEST_SCRIPT_8
--If free space on drive c: is below xxxMB then notify by email 
--	and DELETE all files from c:\DFSC_Test that are older than 7 days LIST remaining files 
--If free space on drive d: is below xxxMB then notify by email 
--	and LIST existing files in d:\DFSC_Test 
--Same for e:\DFSC_Test as for d: (added for @Dirs4FileDel syntax clarity)

exec master.dbo.xp_cmdshell 'copy c:\DFSC_Test_Data\NewFile* c:\DFSC_Test'
exec master.dbo.xp_cmdshell 'copy c:\DFSC_Test_Data\NewFile* d:\DFSC_Test'
exec master.dbo.xp_cmdshell 'copy c:\DFSC_Test_Data\OldFile* c:\DFSC_Test'
exec master.dbo.xp_cmdshell 'copy c:\DFSC_Test_Data\OldFile* d:\DFSC_Test'
exec master.dbo.xp_cmdshell 'mkdir e:\DFSC_Test'
exec master.dbo.xp_cmdshell 'copy c:\DFSC_Test_Data\OldFile* e:\DFSC_Test'
exec master.dbo.xp_cmdshell 'copy c:\DFSC_Test_Data\NewFile* e:\DFSC_Test'

CREATE TABLE #fixeddrives (	drive char(1) PRIMARY KEY,	FreeSpaceMB bigint NOT NULL)
INSERT #fixeddrives (drive, FreeSpaceMB) EXEC master.dbo.xp_fixeddrives
DECLARE @DrivesFreeLimits varchar(100)
-- NO deleting/email  case:
--SELECT @DrivesFreeLimits = 'C::' + cast(FreeSpaceMB - 1 as varchar) 
-- deleting/email  case:
SELECT @DrivesFreeLimits = 'C::' + cast(FreeSpaceMB + 1 as varchar) 
FROM #fixeddrives WHERE drive = 'C'
SELECT @DrivesFreeLimits = @DrivesFreeLimits + '::D::' + cast(FreeSpaceMB + 1 as varchar) 
FROM #fixeddrives WHERE drive = 'D'
SELECT @DrivesFreeLimits
exec aspr_DrivesFreeSpaceControl 	@DefFreeLimitPercent = 0, 
									@DrivesFreeLimits = @DrivesFreeLimits,
									@Dirs4FileDel = 'c:\DFSC_Test::7D::d:\DFSC_Test::::e:\DFSC_Test::',
									@DefLogShrinkThresholdMB = NULL, 
									@DelFilesOnLowSpaceOnly = 1,
							@EMTo = 'vlad@infoplanet-usa.com', 
							@EMCCList = 'victor@hotmail.com;victor@yahoo.com' 
DROP TABLE #fixeddrives 

--Expected results:
--WarnLevel: WARNING
--Subject: Some drives are below free limit after (possible) log shrinking and/or outdated files deleting
--.....
--WarnLevel: NOTIFICATION
--Subject: Files Processing Results for c:\DFSC_Test\
--Details: 
--Path	FileName	Size	LWrDate	Attributes	Status
--c:\DFSC_Test\	NewFile	36182	20051129	32	Skipped
--c:\DFSC_Test\	OldFile	25127	20051123	32	Deleted
--c:\DFSC_Test\	OldFile1	1309221	20051123	32	Deleted
--.....
--WarnLevel: INFO
--Subject: Files Processing Results for d:\DFSC_Test\
--Details: 
--Path	FileName	Size	LWrDate	Attributes	Status
--d:\DFSC_Test\	NewFile	36182	20051129	32	Skipped
--d:\DFSC_Test\	OldFile	25127	20051123	32	Skipped
--d:\DFSC_Test\	OldFile1	1309221	20051123	32	Skipped
--.....
--WarnLevel: INFO
--Subject: Drive Data after cleanup
--Details: 
--Drive	FreeSpaceMB	CapacityMB	FreeLimitMB
--C	136		501		135
--D	478		1999		479
--.......
TEST_SCRIPT_8 end */


/* Pseudo-code
	log input params
	new #DrivesFreeSpaceControl_drives
	new #DrivesFreeSpaceControl_email
	DFSC_SetDrivesFreeSpaceMB(->#DrivesFreeSpaceControl_drives)
	DFSC_SetDrivesCapacityMB(->#DrivesFreeSpaceControl_drives)
	DFSC_SetDrivesFreeLimitsMB(->#DrivesFreeSpaceControl_drives)
	DFSC_LogDrivesSpaceInfo(#DrivesFreeSpaceControl_drives)
	DFSC_AddEmail.Info(#DrivesFreeSpaceControl_drives)
	
	DFSC_TruncateLog
	warn->#DrivesFreeSpaceControl_em
	info->#DrivesFreeSpaceControl_em
	
	DFSC_SetDrivesFreeSpaceMB(->#DrivesFreeSpaceControl_drives)	
	DFSC_LogDrivesInfo(#DrivesFreeSpaceControl_drives)

	new #DrivesFreeSpaceControl_dirs
	DFSC_SetDirs4FileDel(->#DrivesFreeSpaceControl_dirs)
	DFSC_DelFiles(->#DrivesFreeSpaceControl_dirs)
	#DrivesFreeSpaceControl_dirs->#DrivesFreeSpaceControl_em

	DFSC_SetDrivesFreeSpaceMB(->#DrivesFreeSpaceControl_drives)	
	DFSC_LogDrivesInfo(#DrivesFreeSpaceControl_drives)
*/

AS BEGIN
	SET NOCOUNT ON

	DECLARE @proc_name sysname					--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	SELECT @proc_name = name FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int					--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @logmsg nvarchar(255)				-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------
--	DECLARE @hr_obj int							-- var for OAGetErrorInfo

	SET @logmsg = 'Execution of ' + @proc_name
	DECLARE @params_info varchar(1000)
	SET @params_info = '@DefFreeLimitPercent int = ' + isNull(convert(varchar(100), @DefFreeLimitPercent), 'NULL') + CHAR(10)
											+ '@DrivesFreeLimits varchar(2000) = ' + isNull(@DrivesFreeLimits, 'NULL') + CHAR(10)
											+ '@DefLogShrinkThresholdMB bigint = ' + isNull(convert(varchar(100), @DefLogShrinkThresholdMB), 'NULL') + CHAR(10)
											+ '@DBLogsShrinkThresholdsMB varchar(2000) = ' + isNull(@DBLogsShrinkThresholdsMB, 'NULL') + CHAR(10)
											+ '@ShrinkLogOnLowSpaceOnly bit = ' + isNull(convert(varchar(100), @ShrinkLogOnLowSpaceOnly), 'NULL') + CHAR(10)
											+ '@LogNotifyOnly bit = ' + isNull(convert(varchar(100), @LogNotifyOnly), 'NULL') + CHAR(10)
											+ '@EMTo nvarchar(255) = ' + isNull(@EMTo, 'NULL') + CHAR(10)
											+ '@EMCCList nvarchar(1000) = ' + isNull(@EMCCList, 'NULL') + CHAR(10)
											+ '@Dirs4FileDel nvarchar(4000) = ' + isNull(@Dirs4FileDel, 'NULL')+ CHAR(10)
											+ '@DelFilesOnLowSpaceOnly bit = ' + isNull(convert(varchar(100), @DelFilesOnLowSpaceOnly), 'NULL')

	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'DMDBA', 
								@AgentName = @proc_name,
								@Statement = '/**** Input parameters ****/',
								@RecordCount = @rcnt,
								@LogDesc = 	@params_info,
								@UserId = NULL, 
								@IsLogOnly = 1

	SELECT 	@stmnt_lastexec = "CREATE TABLE #DrivesFreeSpaceControl_email (	...."
	CREATE TABLE #DrivesFreeSpaceControl_email (
					ID int IDENTITY(1,1) PRIMARY KEY,
					Subject 	nvarchar(128),	
					WarnLevel	smallint,			--1=Info, 2=Notification, 3=Alert, 4=Warning, 5=Error
					Body		nvarchar(2000) 
				)
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	EXEC aspr_DFSC_AddEmail 	@Subject = 'Input parameters', 
								@WarnLevel = 1,
								@Body = @params_info


	SELECT 	@stmnt_lastexec = "CREATE TABLE #DrivesFreeSpaceControl_drives (	...."
	CREATE TABLE #DrivesFreeSpaceControl_drives (	
					Drive char(1) PRIMARY KEY,	
					FreeSpaceMB bigint, 
					CapacityMB bigint,
					FreeLimitMB bigint
				)
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	SELECT 	@stmnt_lastexec = "exec @err = aspr_DFSC_SetDrivesFreeSpaceMB"
	exec @err = aspr_DFSC_SetDrivesFreeSpaceMB
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 



	SELECT 	@stmnt_lastexec = "exec @err = aspr_DFSC_SetDrivesCapacityMB"
	exec @err = aspr_DFSC_SetDrivesCapacityMB 
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	SELECT 	@stmnt_lastexec = "exec @err = aspr_DFSC_SetDrivesFreeLimitMB @DrivesFreeLimits, @DefFreeLimitPercent"
	exec @err = aspr_DFSC_SetDrivesFreeLimitMB @DrivesFreeLimits, @DefFreeLimitPercent
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	DECLARE @drives_space_info varchar(4000)
	SELECT 	@stmnt_lastexec = "EXEC @err = aspr_DFSC_DrivesSpaceInfo2Str @drives_space_info OUT"
	EXEC @err = aspr_DFSC_DrivesSpaceInfo2Str @drives_space_info OUT
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'DMDBA', 
							@AgentName = @proc_name,
							@Statement = '/**** Initail Drive Data ****/',
							@RecordCount = @rcnt,
							@LogDesc = 	@drives_space_info,
							@UserId = NULL, 
							@IsLogOnly = 1

	EXEC aspr_DFSC_AddEmail 	@Subject = 'Initail Drive Data', 
								@WarnLevel = 1,
								@Body = @drives_space_info


	EXEC aspr_DFSC_ShrinkLog	@DefLogShrinkThresholdMB, @DBLogsShrinkThresholdsMB, @ShrinkLogOnLowSpaceOnly, @LogNotifyOnly

	SELECT 	@stmnt_lastexec = "SELECT nstr1 Path, str2 MinOld, convert(int, NULL) DaysOld INTO #DrivesFreeSpaceControl_dirs..."
	SELECT nstr1 Path, str2 MinOld, convert(int, NULL) DaysOld INTO #DrivesFreeSpaceControl_dirs
	FROM aspr_Iter2CharListToTable(@Dirs4FileDel, '::') 
	ORDER BY nstr1
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	SELECT 	@stmnt_lastexec = "	UPDATE #DrivesFreeSpaceControl_dirs..."
	UPDATE #DrivesFreeSpaceControl_dirs 
		SET DaysOld = cast(left(MinOld, len(MinOld)-1) as int)
		WHERE MinOld <> ''
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	SELECT 	@stmnt_lastexec = "CREATE TABLE #DrivesFreeSpaceControl_files (	...."
	CREATE TABLE #DrivesFreeSpaceControl_files (	
/*	xp_getfiledetails fields	
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
*/				    
--/* spFileDetails fields
						Path nvarchar(4000),
						FileName nvarchar(255),
						ShortPath nvarchar(4000),
						Type VARCHAR(100), 
						DateCreated datetime, 
						DateLastAccessed datetime, 
						DateLastModified datetime,
						Attributes int,	    
						Size int,
--*/
					Status	varchar(10),
					VBErrorInfo nvarchar(1000)
					PRIMARY KEY (Path, FileName)
				) 
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	DECLARE DrivesFreeSpaceControl_dirs_cur CURSOR FOR 
			SELECT Path, DaysOld 
				FROM #DrivesFreeSpaceControl_dirs
	DECLARE @path nvarchar(1000), @days_old int
	OPEN DrivesFreeSpaceControl_dirs_cur
	WHILE (1=1) BEGIN
		FETCH NEXT FROM DrivesFreeSpaceControl_dirs_cur INTO @path, @days_old
		IF (@@FETCH_STATUS <> 0) BREAK

		DECLARE @freespace_limit_diff bigint
		IF (@DelFilesOnLowSpaceOnly = 1) BEGIN
			SELECT @freespace_limit_diff = FreeSpaceMB - FreeLimitMB
				FROM #DrivesFreeSpaceControl_drives WHERE Drive = left(@path,1)
		END
		SET @freespace_limit_diff = isNull(@freespace_limit_diff, 0)
		IF (@DelFilesOnLowSpaceOnly = 0 OR @freespace_limit_diff < 0) BEGIN 
			SELECT 	@stmnt_lastexec = "exec @err = aspr_DFSC_DelOldFiles @path, @days_old"
			exec @err = aspr_DFSC_DelOldFiles @path, @days_old
			SELECT @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err_Close_DrivesFreeSpaceControl_dirs_cur
		END
	END
	CLOSE DrivesFreeSpaceControl_dirs_cur
	DEALLOCATE DrivesFreeSpaceControl_dirs_cur

	SELECT 	@stmnt_lastexec = "exec @err = aspr_DFSC_SetDrivesFreeSpaceMB"
	exec @err = aspr_DFSC_SetDrivesFreeSpaceMB
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	SELECT 	@stmnt_lastexec = "EXEC @err = aspr_DFSC_DrivesSpaceInfo2Str @drives_space_info OUT"
	EXEC @err = aspr_DFSC_DrivesSpaceInfo2Str @drives_space_info OUT
	SELECT @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'DMDBA', 
							@AgentName = @proc_name,
							@Statement = '/**** Drive Data after cleanup ****/',
							@RecordCount = @rcnt,
							@LogDesc = 	@drives_space_info,
							@UserId = NULL, 
							@IsLogOnly = 1

	EXEC aspr_DFSC_AddEmail 	@Subject = 'Drive Data after cleanup', 
								@WarnLevel = 1,
								@Body = @drives_space_info


	IF EXISTS (SELECT * FROM #DrivesFreeSpaceControl_drives 
					WHERE FreeSpaceMB < isNull(FreeLimitMB, CapacityMB*@DefFreeLimitPercent/100)
			) BEGIN
		EXEC aspr_DFSC_AddEmail 	@Subject = 'Some drives are below free limit after (possible) log shrinking and/or outdated files deleting',
									@WarnLevel = 4, 
									@Body = 'Check INFO messages below for details'
	END

	SELECT 	@stmnt_lastexec = "EXEC @err = aspr_DFSC_ProcessEmail @EMTo, @EMCCList "
	EXEC @err = aspr_DFSC_ProcessEmail @EMTo, @EMCCList 
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 

--SELECT * FROM #DrivesFreeSpaceControl_drives
--SELECT * FROM #DrivesFreeSpaceControl_email

	RETURN 0

Err_Close_DrivesFreeSpaceControl_dirs_cur:
	CLOSE DrivesFreeSpaceControl_dirs_cur
	DEALLOCATE DrivesFreeSpaceControl_dirs_cur
Err:
	DECLARE @em_notify nvarchar(1500)
	SET @em_notify = isNull(@EMTo + ';', '') + isNull(@EMCCList, '')
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = 'DMDBA', 
								@AgentName = @proc_name,
								@Statement = @stmnt_lastexec, 
								@ErrCode = @err, 
								@RecordCount = @rcnt, 
								@LogDesc = @logmsg,
								@EMNotify = @em_notify,
								@UserId = NULL

	SET @logmsg = '@logmsg: ' + @logmsg + CHAR(10)
				+ '@stmnt_lastexec: ' + @stmnt_lastexec
	EXEC aspr_DFSC_AddEmail 	@Subject = 'Some error(s) occured!!!',
								@WarnLevel = 5, 
								@Body = @logmsg

	SELECT 	@stmnt_lastexec = "EXEC @err = aspr_DFSC_ProcessEmail @EMTo, @EMCCList "
	EXEC @err = aspr_DFSC_ProcessEmail @EMTo, @EMCCList 
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err 
	
	RETURN @err
END
GO





