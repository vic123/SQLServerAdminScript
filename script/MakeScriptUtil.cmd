::@echo off
call %*
goto :EOF

:MakeFolderScript 
SETLOCAL
::echo And my args: %*
set Folder=%~1
set OutFile=..\SQLAdminSchema.tmp.sql
if not "%~2" == "" set OutFile=%~2
::type %Folder%\SQL_ERR_LOG_Schema.sql >> %OutFile%
::call %Folder%\MakeScript.bat %OutFile%
cd %Folder%
call MakeScript.bat %Folder%Schema.tmp.sql
cd ..
type %Folder%\%Folder%Schema.tmp.sql >> %OutFile%
ENDLOCAL 
goto:eof

:MakeFileScript 
SETLOCAL
set File=%~1
set OutFile=%~2
@echo -->> %OutFile%
@echo -- ****************************** %File% >> %OutFile%
@echo -- >> %OutFile%
type "%File%" >> %OutFile%
ENDLOCAL
goto:eof