@echo off
SETLOCAL
set OutFile=UtilSchema.tmp.sql
if not "%1" == "" set OutFile=%1
type nul > %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript BackupDBList.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript RestoreDBList.sql, %OutFile%
ENDLOCAL
goto:eof
