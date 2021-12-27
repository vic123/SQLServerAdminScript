/*
1 (First Script). Execute the script that follows to create the stored procedures.

NOTE: The following procedure is dependent on SQL Server system tables. The structure 
of these tables change between versions of SQL Server, and selecting directly from 
system tables is discouraged.

NOTE: It should be run on the source server to get script to create PASWORDS and USERS 
on the destination which should then run on destination server.

*/

--USE master
GO
IF OBJECT_ID ('sp_hexadecimal') IS NOT NULL
  DROP PROCEDURE sp_hexadecimal
GO
CREATE PROCEDURE sp_hexadecimal
    @binvalue varbinary(256),
    @hexvalue varchar(256) OUTPUT
AS
DECLARE @charvalue varchar(255)
DECLARE @i int
DECLARE @length int
DECLARE @hexstring char(16)
SELECT @charvalue = '0x'
SELECT @i = 1
SELECT @length = DATALENGTH (@binvalue)
SELECT @hexstring = '0123456789ABCDEF'
WHILE (@i <= @length)
BEGIN
  DECLARE @tempint int
  DECLARE @firstint int
  DECLARE @secondint int
  SELECT @tempint = CONVERT(int, SUBSTRING(@binvalue,@i,1))
  SELECT @firstint = FLOOR(@tempint/16)
  SELECT @secondint = @tempint - (@firstint*16)
  SELECT @charvalue = @charvalue +
    SUBSTRING(@hexstring, @firstint+1, 1) +
    SUBSTRING(@hexstring, @secondint+1, 1)
  SELECT @i = @i + 1
END
SELECT @hexvalue = @charvalue
GO

IF OBJECT_ID ('sp_help_revlogin') IS NOT NULL
  DROP PROCEDURE sp_help_revlogin 
GO
CREATE PROCEDURE sp_help_revlogin @login_name sysname = NULL AS
DECLARE @name    sysname
DECLARE @xstatus int
DECLARE @binpwd  varbinary (255)
DECLARE @txtpwd  sysname
DECLARE @tmpstr  varchar (255)

IF (@login_name IS NULL)
  DECLARE login_curs CURSOR FOR 
    SELECT name, xstatus, password FROM master..sysxlogins 
    WHERE srvid IS NULL AND name <> 'sa'
ELSE
  DECLARE login_curs CURSOR FOR 
    SELECT name, xstatus, password FROM master..sysxlogins 
    WHERE srvid IS NULL AND name = @login_name
OPEN login_curs 
FETCH NEXT FROM login_curs INTO @name, @xstatus, @binpwd
IF (@@fetch_status = -1)
BEGIN
  PRINT 'No login(s) found.'
  CLOSE login_curs 
  DEALLOCATE login_curs 
  RETURN -1
END
SET @tmpstr = '/* sp_help_revlogin script ' 
PRINT @tmpstr
SET @tmpstr = '** Generated ' 
  + CONVERT (varchar, GETDATE()) + ' on ' + @@SERVERNAME + ' */'
PRINT @tmpstr
PRINT ''
PRINT 'DECLARE @pwd sysname'
WHILE (@@fetch_status <> -1)
BEGIN
  IF (@@fetch_status <> -2)
  BEGIN
    PRINT ''
    SET @tmpstr = '-- Login: ' + @name
    PRINT @tmpstr 
    IF (@xstatus & 4) = 4
    BEGIN -- NT authenticated account/group
      IF (@xstatus & 1) = 1
      BEGIN -- NT login is denied access
        SET @tmpstr = 'EXEC master..sp_denylogin ''' + @name + ''''
        PRINT @tmpstr 
      END
      ELSE BEGIN -- NT login has access
        SET @tmpstr = 'EXEC master..sp_grantlogin ''' + @name + ''''
        PRINT @tmpstr 
      END
    END
    ELSE BEGIN -- SQL Server authentication
      IF (@binpwd IS NOT NULL)
      BEGIN -- Non-null password
        EXEC sp_hexadecimal @binpwd, @txtpwd OUT
        IF (@xstatus & 2048) = 2048
          SET @tmpstr = 'SET @pwd = CONVERT (varchar, ' + @txtpwd + ')'
        ELSE
          SET @tmpstr = 'SET @pwd = CONVERT (varbinary, ' + @txtpwd + ')'
        PRINT @tmpstr 
        SET @tmpstr = 'EXEC master..sp_addlogin ''' + @name 
          + ''', @pwd, @encryptopt = '
      END
      ELSE BEGIN 
        -- Null password
        SET @tmpstr = 'EXEC master..sp_addlogin ''' + @name 
          + ''', NULL, @encryptopt = '
      END
      IF (@xstatus & 2048) = 2048
        -- login upgraded from 6.5
        SET @tmpstr = @tmpstr + '''skip_encryption_old''' 
      ELSE 
        SET @tmpstr = @tmpstr + '''skip_encryption'''
      PRINT @tmpstr 
    END
  END
  FETCH NEXT FROM login_curs INTO @name, @xstatus, @binpwd
  END
CLOSE login_curs 
DEALLOCATE login_curs 
RETURN 0
GO 

-- In Query Analyzer, run the following command to get the all logins and passwords

-- EXEC master..sp_help_revlogin 

/*
2. (Second Script)Fixing the Orphaned User Connectios after trasfering the logins and passwords.
*/
/*
declare @usrname varchar(100), @command varchar(100)
declare Crs insensitive cursor for
  select name as UserName from sysusers
	  where issqluser = 1 and (sid is not null and sid <> 0x0)
                    and suser_sname(sid) is null
  order by name
for read only
open Crs
fetch next from Crs into @usrname
	while @@fetch_status=0
begin
--exec sp_change_users_login  @Action =  'Auto_fix', @UserNamePattern = 'sprawki' , @LoginName = NULL, @Password = 'sprawki'
--select @command=' sp_change_users_login  ''auto_fix'', '''+@usrname+''', NULL, ''' + @usrname+''''
select @command=' sp_change_users_login  ''Update_One'', '''+@usrname+''','''+@usrname+''' '
	  exec(@command)
  fetch next from Crs into @usrname
end
	close Crs
deallocate Crs
*/
/*
3 (Third Script) Fixing some Orphaned Users left after step 2.
*/

-- sp_change_users_login 'auto_fix','<user_name>'
-- sp_change_users_login 'update_one','<user_name>','<user_name>'

--exec sp_change_users_login  @Action =  'Update_One', @UserNamePattern = 'users' , @LoginName = 'users'
--exec sp_change_users_login  @Action =  'Auto_fix', @UserNamePattern = 'apteka' , @LoginName = NULL, @Password = 'apteka'
--exec sp_change_users_login  @Action =  'Auto_fix', @UserNamePattern = 'sklad2' , @LoginName = NULL, @Password = 'sklad2'
--exec sp_change_users_login  @Action =  'Auto_fix', @UserNamePattern = 'skladv' , @LoginName = NULL, @Password = 'skladv'






