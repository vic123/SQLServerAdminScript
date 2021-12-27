@echo off
SETLOCAL
set OutFile=EMailSchema.tmp.sql
if not "%1" == "" set OutFile=%1
type nul > %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript SendMail.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript SMTPSendMail.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript CDOSysSendMail.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript CDOSysSendMailFUNC.sql, %OutFile%

ENDLOCAL
goto:eof
