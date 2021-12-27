@echo off
SETLOCAL
set OutFile=ProcessFilesSchema.tmp.sql
if not "%1" == "" set OutFile=%1
type nul > %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ExecXPDirTree.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ProcessFileDetailes_ListZip_7Zip.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ProcessFileDetailes_ListZipRecursive.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ProcessFilesPostCommand_StoreFileList.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ProcessFiles_Delete_v2.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ProcessFiles_UnZip_7Zip.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ProcessFiles_v2.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ProcessFileList_ZipDaily.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript ProcessFiles_Zip_7Zip.sql, %OutFile%
call ..\MakeScriptUtil.cmd :MakeFileScript XCopy.sql, %OutFile%

ENDLOCAL
goto:eof
