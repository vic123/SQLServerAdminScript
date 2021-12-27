@echo off
SETLOCAL
set OutFile=ErrLogSchema.tmp.sql
if not "%1" == "" set OutFile=%1
type nul > %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript SQL_ERR_LOG_Schema.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ADM_GET_SYS_MESSAGE.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ADM_WRITE_SQL_ERR_LOG.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ADM_RPT_SQL_ERR_LOG.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ADM_MAIL_CURSPROC_SQL_ERR_LOG.sql, %OutFile%

ENDLOCAL
goto:eof
