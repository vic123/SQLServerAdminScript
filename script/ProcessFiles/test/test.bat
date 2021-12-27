
.\filetouch /W /S /R /D 09-22-2003 /T 23:00:50 src
echo files would not be added to archive
.\zip.exe -t 2003-09-22 -tt 2003-09-23 -r  -u ".\src_20030922" ".\src\*"
.\filetouch /W /S /R /D 09-21-2003 /T 23:00:50 src
echo files modified on 09-21-2003 will be added to archive for 09-22-2003
.\zip.exe -t 2003-09-22 -tt 2003-09-23 -r  -u ".\src_20030922" ".\src\*"
