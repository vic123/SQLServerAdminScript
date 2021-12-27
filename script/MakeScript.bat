@echo off
set OutFile=SQLAdminSchema.tmp.sql
if not "%1" == "" set OutFile=%1

type nul > %OutFile%

call MakeScriptUtil.cmd :MakeFolderScript ErrLog %OutFile%
call MakeScriptUtil.cmd :MakeFolderScript EMail %OutFile%
call MakeScriptUtil.cmd :MakeFolderScript Util %OutFile%
call MakeScriptUtil.cmd :MakeFolderScript ProcessFiles %OutFile%
call MakeScriptUtil.cmd :MakeFolderScript BackupRestoreDBList %OutFile%
goto:eof
::type ErrLog\SQL_ERR_LOG_Schema.sql >> %OutFile%
call MakeScriptUtil.cmd :MakeFolderScript BTR %OutFile%
call MakeScriptUtil.cmd :MakeFolderScript DFSC %OutFile%
call MakeScriptUtil.cmd :MakeFolderScript ExecuteLargeSQL %OutFile%
call MakeScriptUtil.cmd :MakeFolderScript LogShipping %OutFile%
call MakeScriptUtil.cmd :MakeFolderScript LogTrigger %OutFile%
call MakeScriptUtil.cmd :MakeFolderScript SrvInfo %OutFile%


