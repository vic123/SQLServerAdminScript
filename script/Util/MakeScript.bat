@echo off
SETLOCAL
set OutFile=UtilSchema.tmp.sql
if not "%1" == "" set OutFile=%1
type nul > %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript aspr_Iter2CharListToTable.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript aspr_IterCharListToTable.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript Compare2Tables.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript CreateAndExecTableScript.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript CopyTable.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript create_udfs_functions.sql, %OutFile%
rem call ..\MakeScriptUtil.cmd :MakeFileScript DBObjDeps.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ExecOsql.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ExecXPCmdShell.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript "Fix - Orphaned User Connections_sp3b.sql", %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript generate_inserts.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript IntDT2DT.sql, %OutFile%
rem call ..\MakeScriptUtil.cmd :MakeFileScript space_used.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript VarBinary2Hex.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript OAGetErrorInfo.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript sp_DBCompare.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript sp_dboption2.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript sp_GetCols.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript sp_help_revlogin.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript StringListToTable.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript usp_failed_jobs_report.sql, %OutFile%
ENDLOCAL
goto:eof
