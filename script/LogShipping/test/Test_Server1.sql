EXEC DBBackup_sp @p_type = 'full', @p_database = 'Prod',
					@p_retaindays = 2,
					@p_zipexecprefix = '-afzip, 

--	SET @UNZIP_EXE_CMD = '"C:\Program Files\Winzip\winzip32.exe"' + ' -e '
	SET @UNZIP_EXE_CMD = '"E:\Program Files\Winrar\winrar.exe"' +  ' -y e '

					@p_zipit = 1, 
					@p_dest1 = 'K:\Program Files\Microsoft SQL Server\MSSQL$LCP1\BACKUP\',
					@p_dest2 = '\\vic-w2ks\SharedFolder\LogShipping',
					@p_emailaddress = 'victor@infoplanet-usa.com', @p_emailme = 'Y'


USE Prod
DROP  TABLE tmp
go
CREATE TABLE tmp(a int)
go
INSERT INTO tmp VALUES(1)
go
USE LogShipping
go

EXEC DBBackup_sp @p_type = 'log', @p_database = 'Prod',
					@p_retaindays = 2,
					@p_zippath = NULL, @p_zipit = 0, 
					@p_dest1 = 'K:\Program Files\Microsoft SQL Server\MSSQL$LCP1\BACKUP\',
					@p_dest2 = '\\vic-w2ks\SharedFolder\LogShipping',
					@p_emailaddress = 'victor@infoplanet-usa.com', @p_emailme = 'Y'

Successful Database Backup of Prod - VIC-W2KS\LCP1 Successful log backup of Prod, 
start time Jan 13 2006  4:22PM to Jan 13 2006  4:22PM 
(does not include zip and duplex time)

USE Prod
go
INSERT INTO tmp VALUES(2)
USE LogShipping
go

EXEC DBBackup_sp @p_type = 'log', @p_database = 'Prod',
					@p_cleanuppath = NULL, @p_retaindays = NULL,
					@p_zippath = NULL, @p_zipit = 0, 
					@p_dest1 = 'K:\Program Files\Microsoft SQL Server\MSSQL$LCP1\BACKUP\',
					@p_dest2 = '\\vic-w2ks\SharedFolder\LogShipping',
					@p_emailaddress = 'victor@infoplanet-usa.com', @p_emailme = 'Y'


USE Prod
go
INSERT INTO tmp VALUES(3)
USE LogShipping
go

declare @err int
exec @err = master..xp_cmdshell 'xcopy c:\tmp\* f:\temp\'
SELECT @err



--1st assure that new logins (with same passwords) and users to login mappiungs are created in standby DB
--2nd assure that users are deleted from DB
--3rd logins are deleted only if logins of production are feleted, not only users
--4th user permissions are transferred
--5th roles are created/deleted
--6th users are correctly spread (updated) among roles.

