if exists (select * from sysobjects where name = 'usp_blocking_kill' and type = 'P')
drop procedure usp_blocking_kill
go
create procedure usp_blocking_kill (@b_id int, @KillMSecs int = 0, @KillCount int = 0)
as
declare @spid int, @blocked int, @k_stmnt varchar(100), @mcat varchar(20)
--we shall kill one process only... the things may go on after that... supposed that the @Delay is short enough
	if (@KillMSecs > 0) begin
		select @mcat = 'KillByBlockingMSecs'
		select @spid = blocked from master..sysprocesses
		where waittime = (select max(waittime) from master..sysprocesses where blocked <> 0)
		and waittime > @KillMSecs
		and blocked <> 0
		
		if (@spid is not null) goto KillSP
	end
	if (@KillCount > 0) begin
		select @mcat = 'KillByBlockingCount'
		select @spid = blocked from master..sysprocesses
		where blocked <> 0
		group by blocked
		having count(*) > @KillCount
		order by count(*)
		if (@spid is not null) goto KillSP
	end
	return
KillSP:
	declare @mwaittime int, @bcount int 
	select @blocked = blocked from master..sysprocesses 
	where spid = @spid
	if (@blocked <> 0) insert into btr_LOG(b_id, msg) values (@b_id, @mcat + ': WARNING - killing process that is blocked itself by spid = ' + cast (@blocked as varchar(10)))

	select @bcount = count(*), @mwaittime = max(waittime)
	from master..sysprocesses
	where blocked = @spid
	select @k_stmnt = 'kill ' + cast(@spid as varchar(10))
	exec (@k_stmnt)
	insert into btr_LOG(b_id, msg) values (@b_id, @mcat + ': Killed spid = ' + cast (@spid as varchar(10)) + '. @bcount = ' + cast (@bcount as varchar(10)) + '; @maxwaittime = ' + cast (@mwaittime as varchar(10)))
go

