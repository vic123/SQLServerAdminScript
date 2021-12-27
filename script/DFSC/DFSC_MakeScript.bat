TYPE nul > DFSC_script.tmp.sql
REM CHECK THAT ALL FILES ARE PRESENT

rem ?? COPY util\forfiles.exe "%SystemRoot%\system32"
TYPE ..\ErrLog\_SQLErrLog_script.tmp.sql >> DFSC_script.tmp.sql
TYPE util\sp_EmailAlert2.sql >> DFSC_script.tmp.sql
TYPE util\audf_VarBinary2Hex.sql  >> DFSC_script.tmp.sql
TYPE util\aspr_OAGetErrorInfo.sql >> DFSC_script.tmp.sql
TYPE util\aspr_IterCharListToTable.sql >> DFSC_script.tmp.sql
TYPE util\aspr_Iter2CharListToTable.sql >> DFSC_script.tmp.sql
TYPE util\aspr_DrivesCapacityMB_ListParam.sql >> DFSC_script.tmp.sql
TYPE util\spFileDetails >> DFSC_script.tmp.sql

TYPE DFSC_Util.sql >> DFSC_script.tmp.sql
TYPE aspr_DFSC_ProcessEmail.sql >> DFSC_script.tmp.sql
TYPE aspr_DFSC_SetDrivesCapacityMB.sql >> DFSC_script.tmp.sql
TYPE aspr_DFSC_SetDrivesFreeLimitMB.sql >> DFSC_script.tmp.sql
TYPE aspr_DFSC_SetDrivesFreeSpaceMB.sql >> DFSC_script.tmp.sql
TYPE aspr_DFSC_ShrinkLog.sql  >> DFSC_script.tmp.sql

TYPE aspr_DFSC_DelOldFiles.sql  >> DFSC_script.tmp.sql
TYPE aspr_DrivesFreeSpaceControl.sql >> DFSC_script.tmp.sql
TYPE test\aspr_GetLogicalLogNameAndDrive.sql >> DFSC_script.tmp.sql
TYPE test\aspr_LogGrowSimulation.sql >> DFSC_script.tmp.sql


