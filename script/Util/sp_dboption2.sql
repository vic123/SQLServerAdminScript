IF OBJECT_ID('sp_dboption2') IS NOT NULL  
  DROP PROC sp_dboption2
GO

CREATE PROC sp_dboption2
(
	@dbname		sysname		= NULL,		--Database name
	@optname	varchar(35)	= NULL,		--Option name
	@optvalue	varchar(5)	= NULL,		--Option value, either 'true' or 'false'
	@wait		int		= NULL		--Seconds to wait, before killing the existing connections
)
AS
BEGIN
/***********************************************************************************************************
		Copyright 2001 Narayana Vyas Kondreddi. All rights reserved.
                                          
Purpose:	The system stored procedure sp_dboption fails to set databases in 'read only'/'single user'/'offline' 
		modes if the database is in use. This procedure works as a wrapper around sp_dboption and overcomes that
		limitation by killing all the active connections. You can configure it to kill the connections immediately, 
		or after waiting for a specified interval. This procedure simulates the new ALTER TABLE syntax of SQL Server
		2000 (the ROLLBACK IMMEDIATE and ROLLBACK AFTER options along with OFFLINE, ONLINE, READ_ONLY, READ_WRITE,
		SINGLE_USER, RESTRICTED_USER, MULTI_USER). 

Written by:	Narayana Vyas Kondreddi
		http://vyaskn.tripod.com

Tested on: 	SQL Server 7.0, Service Pack 3

Date created:	October-29-2001 1:30 AM Indian Standard Time
Date modified:	October-29-2001 1:30 AM Indian Standard Time

Email: 		vyaskn@hotmail.com

Usage: 		Just run this complete script in the master database to create this stored procedure. As far as syntax is 
		concerned, this procedure works very similar to the system stored procedure sp_dboption. It has an additional
		parameter @wait, which can be used, to wait for a specified number of seconds, before killing the connections.
		The settable database option names need to be specified in full. For example, the option name 'single' is
		considered invalid and 'single user' is considered valid.
		
		To bring pubs database into single user mode:

		EXEC sp_dboption2 'pubs', 'single user', 'true'

		To bring pubs database into single user mode. Wait for 30 seconds, for current connections to leave and
		start killing the connections after 30 seconds:

		EXEC sp_dboption2 'pubs', 'single user', 'true', 30

		To bring pubs database into read/write mode:

		EXEC sp_dboption2 'pubs', 'read only', 'false'

		To bring pubs database into read/write mode. Wait for 30 seconds, for current connections to leave and
		start killing the connections after 30 seconds:

		EXEC sp_dboption2 'pubs', 'read only', 'false', 30


***********************************************************************************************************/
	DECLARE @dbid int, @spid int, @execstr varchar(15), @waittime varchar(15), @final_chk int
	
	--Only the following options require that, no other connections should access the database 
	IF (LOWER(@optname) IN ('offline', 'read only', 'single user')) AND (LOWER(@optvalue) IN('true', 'false'))
	BEGIN
			--Determining whether to wait, before killing the existing connections
			IF @wait > 0
			BEGIN
				SET @waittime = (SELECT CONVERT(varchar, DATEADD(s, @wait, GETDATE()), 14))
				WAITFOR TIME @waittime --Wait the specified number of seconds		
			END
				
			SET @dbid = DB_ID(@dbname) --Getting the database_id for the specified database

			--Get the lowest spid
			TryAgain:
			SET @spid = (SELECT MIN(spid) FROM master..sysprocesses WHERE dbid = @dbid)

			WHILE @spid IS NOT NULL
			BEGIN
				IF @spid <> @@SPID --To avoid the KILL attempt on own connection
				BEGIN
					SET @execstr = 'KILL ' + LTRIM(STR(@spid))
					EXEC(@execstr) --Killing the connection
				END
				--Get the spid higher than the last spid
				SET @spid = (SELECT MIN(spid) FROM master..sysprocesses WHERE dbid = @dbid AND spid > @spid)
			END

	END
	
	SET @final_chk = (SELECT COUNT(spid) FROM master..sysprocesses WHERE dbid = @dbid)
	IF (@final_chk = 0) OR (@final_chk = 1 AND DB_NAME() = @dbname)
	BEGIN
		EXEC sp_dboption @dbname, @optname, @optvalue --Calling sp_dboption to complete the job
	END
	ELSE
	BEGIN
		GOTO TryAgain --New connections popped up, or killed connections aren't cleaned up yet, so try killing them again
	END
END

GO

