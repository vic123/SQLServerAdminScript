if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[usp_KillUsers]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[usp_KillUsers]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[usp_LogShipping_Continue]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[usp_LogShipping_Continue]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[usp_LogShipping_Finish]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[usp_LogShipping_Finish]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[usp_LogShipping_Init]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[usp_LogShipping_Init]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[usp_LogShipping_Monitor]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[usp_LogShipping_Monitor]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SendMail_sp]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SendMail_sp]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[LogShipping_Audit]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[LogShipping_Audit]
GO

CREATE TABLE [dbo].[LogShipping_Audit] (
	[seq] [int] IDENTITY (1, 1) NOT NULL ,
	[status] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[applydate] [datetime] NOT NULL ,
	[dbname] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[dbtype] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[lastfilename] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[command] [varchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[LogShipping_Audit] WITH NOCHECK ADD 
	CONSTRAINT [PK_LogShipping_Audit] PRIMARY KEY  CLUSTERED 
	(
		[seq]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
GO

ALTER TABLE [dbo].[LogShipping_Audit] ADD 
	CONSTRAINT [DF_LogShipping_Audit_applydate] DEFAULT (getdate()) FOR [applydate]
GO


SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO


CREATE procedure usp_LogShipping_Init 
	@dbname varchar(50)  = 'error'
	,@backuppath varchar(250) 
	,@standbyfile varchar(450) 
	,@fileprefix varchar(50) = 'pad_'
	,@allbackuppostfix varchar(50) = '.bak*'
	,@fullbackuppostfix varchar(50) = '_full.bak'
	,@diffbackuppostfix varchar(50) = '_dif.bak'
	,@logbackuppostfix varchar(50) = '_trn.bak'
	,@fullbackupmovecommand varchar(550) = '   MOVE ''PAD_Data'' TO ''c:\test_data01.mdf'',   MOVE ''PAD_Log'' TO ''c:\test_log01.ndf'' '
--060323	,@zippath varchar(100) = null
	,@zipexecprefix varchar(100) = null
as

set nocount on

declare @sqlstring varchar(4000)
declare @restore_filename varchar(425)
declare @backups cursor
declare @seq int
declare @found_full int
declare @error int

create table #filelist (seq int identity(1,1), backupfilename varchar(255))

set @sqlstring = 'dir /o /b ' + @backuppath + @fileprefix + '*' + @allbackuppostfix
insert into #filelist (backupfilename)
exec master..xp_cmdshell @sqlstring

delete from #filelist where backupfilename is null

--
-- Locate and restore FULL backup
--

set @backups = CURSOR SCROLL DYNAMIC
	FOR
		select max(seq), backupfilename 
		from #filelist 
		where charindex(@fullbackuppostfix, backupfilename) > 0
		group by backupfilename
		order by 1 desc

open @backups
fetch next from @backups into @seq, @restore_filename

set @found_full = 0
if @@fetch_status = 0 and @found_full = 0
begin
/*		IF EXISTS (SELECT * FROM master..sysdatabases WHERE name = @dbname) BEGIN 
			set @sqlstring =  'alter database ' + @dbname + ' set RESTRICTED_USER with rollback immediate'
			exec (@sqlstring)
			set @sqlstring =  'alter database ' + @dbname + ' set MULTI_USER with rollback immediate'
			exec (@sqlstring)
		END
*/
		-- check file isnt zipped, if so decompress & restore 	
		if charindex('.gz', @restore_filename) > 0 or charindex('.zip', @restore_filename) > 0
		begin
--060323			SELECT @sqlstring = @zippath + '\gzip.exe -d ' + @backuppath + @restore_filename 
			SELECT @sqlstring = @zipexecprefix + ' ' + @backuppath + @restore_filename 

			EXEC @error = master..xp_cmdshell @sqlstring, NO_OUTPUT

			set @restore_filename = replace(@restore_filename, '.gz', '')
			set @restore_filename = replace(@restore_filename, '.zip', '')
		end

		--set @sqlstring =  'alter database ' + @dbname + ' set RESTRICTED_USER with rollback immediate'
		--exec (@sqlstring)

		set @sqlstring = 'RESTORE DATABASE ' + @dbname + ' ' +
				'FROM DISK= ''' + @backuppath + @restore_filename + ''' ' + 
				'WITH ' + @fullbackupmovecommand + ' , STANDBY = ''' + @standbyfile + ''''
		exec (@sqlstring)

		if @@error <> 0
			insert into LogShipping_Audit (status, dbname, dbtype, lastfilename, command) values ('FAILURE', @dbname, 'FULL', @restore_filename, @sqlstring)
		else	
			insert into LogShipping_Audit (status, dbname, dbtype, lastfilename, command) values ('SUCCESS', @dbname, 'FULL', @restore_filename, @sqlstring)

		set @found_full = @seq
end
else
	insert into LogShipping_Audit (status, dbname, dbtype, command) values ('WARNING', @dbname, 'FULL', 'No full backup file found for database')	

close @backups
deallocate @backups

--
-- Locate and restore last DIFF backup
--

set @backups = CURSOR SCROLL DYNAMIC
	FOR
		select max(seq), backupfilename 
		from #filelist 
		where charindex(@diffbackuppostfix, backupfilename) > 0
		and seq > @found_full
		group by backupfilename

open @backups
fetch next from @backups into @seq, @restore_filename

if @@fetch_status = 0 and @found_full > 0
begin
		-- check file isnt zipped, if so decompress & restore 	
		if charindex('.gz', @restore_filename) > 0 or charindex('.zip', @restore_filename) > 0
		begin
--060323			SELECT @sqlstring = @zippath + '\gzip.exe -d ' + @backuppath + @restore_filename 
			SELECT @sqlstring = @zipexecprefix + ' ' + @backuppath + @restore_filename 
			EXEC @error = master..xp_cmdshell @sqlstring, NO_OUTPUT

			set @restore_filename = replace(@restore_filename, '.gz', '')
			set @restore_filename = replace(@restore_filename, '.zip', '')
		end

		set @sqlstring = 'exec usp_KillUsers ''' + @dbname + ''''
		exec (@sqlstring)

		set @sqlstring = 'RESTORE DATABASE ' + @dbname + ' ' +
				'FROM DISK= ''' + @backuppath + @restore_filename + ''' ' + 
				'WITH ' + @fullbackupmovecommand + ' , STANDBY = ''' + @standbyfile + ''''
		exec (@sqlstring)

		if @@error <> 0
			insert into LogShipping_Audit (status, dbname, dbtype, lastfilename, command) values ('ERROR', @dbname, 'DIFF', @restore_filename, @sqlstring)
		else
			insert into LogShipping_Audit (status, dbname, dbtype, lastfilename, command) values ('SUCCESS', @dbname, 'DIFF', @restore_filename, @sqlstring)

		set @found_full = @seq -- diff is regarded as a "full" in terms of subsequent log recovery
end

close @backups
deallocate @backups

--
-- process tran logs
--

if @found_full <> 0 and @found_full <> (select max(seq) from #filelist)
begin
	
	set @backups = CURSOR SCROLL DYNAMIC
	FOR
		select seq, backupfilename 
		from #filelist 
		where seq > @found_full
		order by seq asc

	open @backups
	fetch next from @backups into @seq, @restore_filename
	
	while @@fetch_status = 0 and @found_full > 0
	begin

		if charindex(@logbackuppostfix, @restore_filename) > 0
		begin
			-- check file isnt zipped, if so decompress & restore 	
			if charindex('.gz', @restore_filename) > 0 or charindex('.zip', @restore_filename) > 0
			begin
--060323				SELECT @sqlstring = @zippath + '\gzip.exe -d ' + @backuppath + @restore_filename 
				SELECT @sqlstring = @zipexecprefix + ' ' + @backuppath + @restore_filename 
				EXEC @error = master..xp_cmdshell @sqlstring, NO_OUTPUT
	
				set @restore_filename = replace(@restore_filename, '.gz', '')
				set @restore_filename = replace(@restore_filename, '.zip', '')
			end

			set @sqlstring = 'exec usp_KillUsers ''' + @dbname + ''''
			exec (@sqlstring)

			set @sqlstring = 'RESTORE LOG ' + @dbname + ' ' +
					'FROM DISK= ''' + @backuppath + @restore_filename + ''' ' + 
					'WITH STANDBY = ''' + @standbyfile + ''''
			exec (@sqlstring)

			if @@error <> 0 begin
				insert into LogShipping_Audit (status, dbname, dbtype, lastfilename, command) values ('ERROR', @dbname, 'LOG', @restore_filename, @sqlstring)
			end
			else	
				insert into LogShipping_Audit (status, dbname, dbtype, lastfilename, command) values ('SUCCESS', @dbname, 'LOG', @restore_filename, @sqlstring)
		end
			-- else log an error and email dba
		
		fetch next from @backups into @seq, @restore_filename
	end

	close @backups
	deallocate @backups

end

drop table #filelist
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


CREATE PROCEDURE usp_KillUsers @dbname varchar(50), @hostname varchar(100) = null as
SET NOCOUNT ON

DECLARE @strSQL varchar(255)
PRINT 'Killing Users'
PRINT '-----------------'

CREATE table #tmpUsers(
spid int,
eid int,
status varchar(30),
loginname varchar(50),
hostname varchar(100),
blk int,
dbname varchar(50),
cmd varchar(30))

INSERT INTO #tmpUsers EXEC SP_WHO


DECLARE LoginCursor CURSOR
READ_ONLY
FOR SELECT spid, dbname,hostname FROM #tmpUsers WHERE dbname = @dbname

DECLARE @spid varchar(10)
DECLARE @dbname2 varchar(40)
DECLARE @userhost varchar(100)
OPEN LoginCursor

FETCH NEXT FROM LoginCursor INTO @spid, @dbname2, @userhost
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		if @hostname is null begin
			PRINT 'Killing ' + @spid
			SET @strSQL = 'KILL ' + @spid
			EXEC (@strSQL)
		end
		else if @userhost is not null and @hostname = @userhost begin		
			PRINT 'Killing ' + @spid
			SET @strSQL = 'KILL ' + @spid
			EXEC (@strSQL)
		end
	END
	FETCH NEXT FROM LoginCursor INTO @spid, @dbname2, @userhost
END

CLOSE LoginCursor
DEALLOCATE LoginCursor

DROP table #tmpUsers

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO


CREATE procedure usp_LogShipping_Continue 
	@dbname varchar(50) = 'padtest'
	,@backuppath varchar(250) = 'c:\testbackups\'
	,@standbyfile varchar(450) = 'c:\pad_standby.rdo'
	,@fileprefix varchar(50) = 'pad_'
	,@allbackuppostfix varchar(50) = '.bak'
	,@fullbackuppostfix varchar(50) = '_full.bak'
	,@diffbackuppostfix varchar(50) = '_dif.bak'
	,@logbackuppostfix varchar(50) = '_trn.bak'
	,@fullbackupmovecommand varchar(550) = '   MOVE ''PAD_Data'' TO ''c:\test_data01.mdf'',   MOVE ''PAD_Log'' TO ''c:\test_log01.ndf'' '
--060323	,@zippath varchar(100) = 'c:\scripts\'
	,@zipexecprefix varchar(100) = null
as

--060323	@standbyfile = @standbyfile + @dbname + '.RackomDaiOblom'

declare @type varchar(25)
declare @lastrestorefilename varchar(455)
declare @sqlstring varchar(4000)
declare @restore_filename varchar(425)
declare @backups cursor
declare @seq int
declare @found_full int
declare @error int

-- DB Still exists ?
if (select count(*) from master..sysdatabases where name = @dbname) <= 0
begin
	insert into LogShipping_Audit (status, dbname, dbtype, lastfilename, command) values ('SUCCESS', @dbname, 'REINIT', null, 'Database was missing ?')
--060323	exec usp_LogShipping_Init @dbname,@backuppath,@standbyfile,@fileprefix,@allbackuppostfix,@fullbackuppostfix,@diffbackuppostfix,@logbackuppostfix,@fullbackupmovecommand,@zippath
	exec usp_LogShipping_Init @dbname,@backuppath,@standbyfile,@fileprefix,@allbackuppostfix,@fullbackuppostfix,@diffbackuppostfix,@logbackuppostfix,@fullbackupmovecommand,@zipexecprefix
end
else
begin

	--
	-- locate last applied file
	--
	set @backups = CURSOR SCROLL DYNAMIC
		FOR
			select max(seq), dbtype, lastfilename 
			from LogShipping_Audit 
			where dbname = @dbname
			and	lastfilename is not null
			and status = 'SUCCESS'
			-- to do, check for ERROR between last full/diff and current
			group by dbtype, lastfilename 
			order by 1 desc
	
	create table #filelist (seq int identity(1,1), backupfilename varchar(255))
	
	open @backups
	fetch next from @backups into @seq, @type, @lastrestorefilename
	if @@fetch_status = 0
	begin
		-- get current file list
		-- minus last recovered file and restore to standby mode
	
		set @sqlstring = 'dir /o /b ' + @backuppath + @fileprefix + '*' + @allbackuppostfix
		insert into #filelist (backupfilename)
		exec master..xp_cmdshell @sqlstring
	
		delete from #filelist where backupfilename is null
	
		delete from #filelist
		where seq <= (select seq from #filelist where backupfilename = @lastrestorefilename)
	end
	
	close @backups
	deallocate @backups
	
	-- FULL done since initial INIT ?  if so, call init and start process again
	if (select count(*) from #filelist where charindex(@fullbackuppostfix, backupfilename) > 0) > 0
	begin
		insert into LogShipping_Audit (status, dbname, dbtype, lastfilename, command) values ('SUCCESS', @dbname, 'REINIT', null, 'Found another full backup, reinitiatizing log shipping')
--060323		exec usp_LogShipping_Init @dbname,@backuppath,@standbyfile,@fileprefix,@allbackuppostfix,@fullbackuppostfix,@diffbackuppostfix,@logbackuppostfix,@fullbackupmovecommand,@zippath
		exec usp_LogShipping_Init @dbname,@backuppath,@standbyfile,@fileprefix,@allbackuppostfix,@fullbackuppostfix,@diffbackuppostfix,@logbackuppostfix,@fullbackupmovecommand,@zipexecprefix
	end
	else
	begin	
		--
		-- Locate and restore last DIFF backup
		--
		
		set @backups = CURSOR SCROLL DYNAMIC
			FOR
				select max(seq), backupfilename 
				from #filelist 
				where charindex(@diffbackuppostfix, backupfilename) > 0
				group by backupfilename
		
		open @backups
		fetch next from @backups into @seq, @restore_filename
		
		set @found_full = -9999
		
		if @@fetch_status = 0 
		begin
				-- check file isnt zipped, if so decompress & restore 	
				if charindex('.gz', @restore_filename) > 0 or charindex('.zip', @restore_filename) > 0
				begin
--060323					SELECT @sqlstring = @zippath + '\gzip.exe -d ' + @backuppath + @restore_filename 
					SELECT @sqlstring = @zipexecprefix + ' ' + @backuppath + @restore_filename 
					EXEC @error = master..xp_cmdshell @sqlstring, NO_OUTPUT
		
					set @restore_filename = replace(@restore_filename, '.gz', '')
					set @restore_filename = replace(@restore_filename, '.zip', '')
				end
	
				set @sqlstring = 'exec usp_KillUsers ''' + @dbname + ''''
				exec (@sqlstring)
		
				set @sqlstring = 'RESTORE DATABASE ' + @dbname + ' ' +
						'FROM DISK= ''' + @backuppath + @restore_filename + ''' ' + 
						'WITH ' + @fullbackupmovecommand + ' , STANDBY = ''' + @standbyfile + ''''
				exec (@sqlstring)
		
				if @@error <> 0
					insert into LogShipping_Audit (status, dbname, dbtype, lastfilename, command) values ('ERROR', @dbname, 'DIFF', @restore_filename, @sqlstring)
				else
					insert into LogShipping_Audit (status, dbname, dbtype, lastfilename, command) values ('SUCCESS', @dbname, 'DIFF', @restore_filename, @sqlstring)
		
				set @found_full = @seq -- diff is regarded as a "full" in terms of subsequent log recovery
		end
		
		close @backups
		deallocate @backups
		
		--
		-- process tran logs
		--
		
			set @backups = CURSOR SCROLL DYNAMIC
			FOR
				select seq, backupfilename 
				from #filelist 
				where seq > @found_full
				order by seq asc
		
			open @backups
			fetch next from @backups into @seq, @restore_filename
			
			while @@fetch_status = 0 
			begin
		
				if charindex(@logbackuppostfix, @restore_filename) > 0
				begin
					-- check file isnt zipped, if so decompress & restore 	
					if charindex('.gz', @restore_filename) > 0 or charindex('.zip', @restore_filename) > 0
					begin
--060323						SELECT @sqlstring = @zippath + '\gzip.exe -d ' + @backuppath + @restore_filename 
						SELECT @sqlstring = @zipexecprefix + ' ' + @backuppath + @restore_filename 
						EXEC @error = master..xp_cmdshell @sqlstring, NO_OUTPUT
			
						set @restore_filename = replace(@restore_filename, '.gz', '')
						set @restore_filename = replace(@restore_filename, '.zip', '')
					end
	
					set @sqlstring = 'exec usp_KillUsers ''' + @dbname + ''''
					exec (@sqlstring)
		
					set @sqlstring = 'RESTORE LOG ' + @dbname + ' ' +
							'FROM DISK= ''' + @backuppath + @restore_filename + ''' ' + 	
							'WITH STANDBY = ''' + @standbyfile + ''''
					exec (@sqlstring)
		
					if @@error <> 0
						insert into LogShipping_Audit (status, dbname, dbtype, lastfilename, command) values ('ERROR', @dbname, 'LOG', @restore_filename, @sqlstring)
					else	
						insert into LogShipping_Audit (status, dbname, dbtype, lastfilename, command) values ('SUCCESS', @dbname, 'LOG', @restore_filename, @sqlstring)
				end
					-- else log an error and email dba
				
				fetch next from @backups into @seq, @restore_filename
			end
		
			close @backups
			deallocate @backups
		
	end
end

--drop table #filelist
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO


CREATE procedure usp_LogShipping_Finish @dbname varchar(25)
as
	declare @sqlstring varchar(100)

	if exists(select 'x' from master..sysdatabases where name = @dbname and status = 2098196)
	begin
		set @sqlstring = 'exec usp_KillUsers ''' + @dbname + ''''
		exec (@sqlstring)

		set @sqlstring = 'restore database ' + @dbname + ' with recovery'
		exec (@sqlstring)
		
		insert into LogShipping_Audit (status, dbname, dbtype, command) values ('SUCCESS', @dbname, 'RECOVERED', @sqlstring)
	end
	else
		insert into LogShipping_Audit (status, dbname, dbtype, command) values ('FAILED', @dbname, 'RECOVERY', 'Database not found or DB not in standby mode')

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO


CREATE PROCEDURE SendMail_sp (@PFROM NVARCHAR(255), @PTO NVARCHAR(255), @PSUBJECT NVARCHAR(255), @PBODY NVARCHAR(4000), @pattachmentfilename nvarchar(1000) = null) AS

	DECLARE @msg nvarchar (4000)
	SET @msg = @PSUBJECT + CHAR(10) + @PBODY
	EXEC sp_EmailAlert2 @ModuleName = 'LogShipping', @Msg = @msg, @CcList =  @PTO
/*
declare @object int,
 @hr int,
 @rc int,
 @output varchar(400),
 @description varchar (400),
 @source varchar(400),
 @v_returnval varchar(1000),
 @serveraddress varchar(1000)

	set @serveraddress = '163.232.6.188'

	exec @hr = sp_OACreate 'SimpleCDO.Message', @object OUT

	if @pattachmentfilename is null or @pattachmentfilename = ''
		exec @hr = sp_OAMethod @object, 'SendMessage', @v_returnval OUT, @PTO, @PFROM, @PSUBJECT, @PBODY, @serveraddress, @v_returnval
	else
		exec @hr = sp_OAMethod @object, 'SendMessageWithAttachment', @v_returnval OUT, @PTO, @PFROM, @PSUBJECT, @PBODY, @serveraddress, @pattachmentfilename, @v_returnval
	
	exec @hr = sp_OADestroy @object
*/
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO



SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO


CREATE procedure usp_LogShipping_Monitor 
		@p_email_address varchar(255),
		@p_subjectprefix varchar(255),
		@p_period int = 10 
as
begin
	declare @v_errortext varchar(4000)

	set @p_subjectprefix = @p_subjectprefix + ' - Monitoring Email'
	set @v_errortext = (select max(status+ ' : ' + dbname + ' : ' + dbtype + ' : ' + command) from LogShipping_Audit where applydate >= DATEADD (mi, @p_period - @p_period - @p_period, getdate()) and status in ('ERROR','FAILURE', 'WARNING') )

	if @v_errortext is not null
		exec SendMail_sp @@SERVERNAME,@p_email_address, @p_subjectprefix, @v_errortext
end
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO
