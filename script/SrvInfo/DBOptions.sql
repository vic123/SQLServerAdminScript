/*
By: iecdba 
This SELECT will give you a summarized report for the options selected for ALL the databases on your SQL Server. It's compatible with versions 7 and 2000. 

*/

SELECT LEFT(name,30) AS DB, 
        SUBSTRING(CASE status & 1 WHEN 0 THEN '' ELSE ',autoclose' END + 
        CASE status & 4 WHEN 0 THEN '' ELSE ',select into/bulk copy' END + 
        CASE status & 8 WHEN 0 THEN '' ELSE ',trunc. log on chkpt' END + 
        CASE status & 16 WHEN 0 THEN '' ELSE ',torn page detection' END + 
        CASE status & 32 WHEN 0 THEN '' ELSE ',loading' END + 
        CASE status & 64 WHEN 0 THEN '' ELSE ',pre-recovery' END + 
        CASE status & 128 WHEN 0 THEN '' ELSE ',recovering' END + 
        CASE status & 256 WHEN 0 THEN '' ELSE ',not recovered' END + 
        CASE status & 512 WHEN 0 THEN '' ELSE ',offline' END + 
        CASE status & 1024 WHEN 0 THEN '' ELSE ',read only' END + 
        CASE status & 2048 WHEN 0 THEN '' ELSE ',dbo USE only' END + 
        CASE status & 4096 WHEN 0 THEN '' ELSE ',single user' END + 
        CASE status & 32768 WHEN 0 THEN '' ELSE ',emergency mode' END + 
        CASE status & 4194304 WHEN 0 THEN '' ELSE ',autoshrink' END + 
        CASE status & 1073741824 WHEN 0 THEN '' ELSE ',cleanly shutdown' END + 
        CASE status2 & 16384 WHEN 0 THEN '' ELSE ',ANSI NULL default' END + 
        CASE status2 & 65536 WHEN 0 THEN '' ELSE ',concat NULL yields NULL' END + 
        CASE status2 & 131072 WHEN 0 THEN '' ELSE ',recursive triggers' END + 
        CASE status2 & 1048576 WHEN 0 THEN '' ELSE ',default TO local cursor' END + 
        CASE status2 & 8388608 WHEN 0 THEN '' ELSE ',quoted identifier' END + 
        CASE status2 & 33554432 WHEN 0 THEN '' ELSE ',cursor CLOSE on commit' END + 
        CASE status2 & 67108864 WHEN 0 THEN '' ELSE ',ANSI NULLs' END + 
        CASE status2 & 268435456 WHEN 0 THEN '' ELSE ',ANSI warnings' END + 
        CASE status2 & 536870912 WHEN 0 THEN '' ELSE ',full text enabled' END, 
2,8000) AS Descr 
FROM master..sysdatabases 

