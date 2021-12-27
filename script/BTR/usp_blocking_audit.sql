if exists (select * from sysobjects where name = 'usp_blocking_audit' and type = 'P')
drop procedure usp_blocking_audit
go
create procedure usp_blocking_audit (
@Action varchar(10) = NULL,
@Delay datetime = NULL, --'00:00:30'
@ActionTrace bit = NULL, --1
@PreBlockCount int = 0,		--must be 0, don't work yet (do we need it? - not very usefull because of expecting overload)
@ActionKill bit = NULL, --0
@KillMSecs int = NULL,	--0	--(milliseconds)
@KillCount int = NULL --0
, @MaxCPU int	= NULL --100 ms per second 
, @SJHTraceFreq int	= NULL --10 - save sysjobhistory once per 10 cycles of BTR execution. 
, @DoLockTrace bit = NULL --0 save locks info 
)
as
set nocount on
declare @debug bit
select  @debug = 0
declare @b_id int
declare @ph_id int --params history 
declare @ActionStop bit

if (upper(@Action) = 'CONTROL') begin
	if not exists (select * from btr_Params join master..sysprocesses 
				on Value = convert(varchar(23), login_time, 21) 
					+ '_' + convert(varchar(6), spid)
			where btr_Params.Name = 'Running'
		) print 'WARNING: Procedure is NOT running according to record in btr_Params'
	insert into btr_PHistory (action, time, uname) select 'CONTROL', getdate(), user_name()
	SELECT @ph_id = @@IDENTITY
	if @Delay is not null
		insert into btr_Params (ph_id, Name, Value) select @ph_id, 'Delay', convert(nvarchar(100), @Delay, 21)
	if @ActionTrace is not null
		insert into btr_Params (ph_id, Name, Value) select @ph_id, 'ActionTrace', cast (@ActionTrace as nvarchar(255))
	if @ActionKill is not null
		insert into btr_Params (ph_id, Name, Value) select @ph_id, 'ActionKill', cast (@ActionKill as nvarchar(255))
	if @KillMSecs is not null
		insert into btr_Params (ph_id, Name, Value) select @ph_id, 'KillMSecs', cast (@KillMSecs as nvarchar(255))
	if @KillCount is not null
		insert into btr_Params (ph_id, Name, Value) select @ph_id, 'KillCount' , cast (@KillCount as nvarchar(255))
	if @MaxCPU is not null
		insert into btr_Params (ph_id, Name, Value) select @ph_id, 'MaxCPU' , cast (@MaxCPU as nvarchar(255))
	if @SJHTraceFreq is not null
		insert into btr_Params (ph_id, Name, Value) select @ph_id, 'SJHTraceFreq' , cast (@SJHTraceFreq as nvarchar(255))
	if @DoLockTrace is not null
		insert into btr_Params (ph_id, Name, Value) select @ph_id, 'DoLockTrace' , cast (@DoLockTrace as nvarchar(255))
	print 'usp_blocking_audit parameters updated on ' + cast (getdate() as nvarchar(255)) + ':'
	select * from btr_Params where ph_id = @ph_id	
	return 0
end


if (upper(@Action) = 'STOP') begin
	if not exists (select * from btr_Params join master..sysprocesses 
				on Value = convert(varchar(23), login_time, 21) 
					+ '_' + convert(varchar(6), spid)
			where btr_Params.Name = 'Running'
		) print 'WARNING: Procedure is NOT running according to record in btr_Params'
		insert into btr_PHistory (action, time, uname) select 'STOP', getdate(), user_name()
		SELECT @ph_id = @@IDENTITY
		insert into btr_Params (ph_id, Name, Value) select @ph_id, 'ActionStop', '1'
	return 0
end

if (upper(@Action) = 'START') begin
/******************************* INITIALIZATION *********************************/
--stop IF previous instance IS running occasionally
	if exists (select * from btr_Params join master..sysprocesses 
			on Value = convert(varchar(23), login_time, 21) 
				+ '_' + convert(varchar(6), spid)
			where btr_Params.Name = 'Running') begin
		print 'usp_blocking_audit is running. Exec usp_blocking_audit  @Action = ''STOP'' first'
		--(MOD-030613)beg
		insert into btr_LOG(b_id, msg) 
		select max(b_id), 
			'audit: Process ' + convert(varchar(10), @@spid) + ' detected another BTR: ' 
			+ isnull ((select btr_Params.Value from btr_Params join master..sysprocesses 
				on Value = convert(varchar(23), login_time, 21) 
				+ '_' + convert(varchar(6), spid) where btr_Params.Name = 'Running'), ' ')
			from btr_Batch
		--(MOD-030613)end
		return -1
	end
	insert into btr_PHistory (action, time, uname) select 'START', getdate(), user_name()
	SELECT @ph_id = @@IDENTITY
	insert into btr_Params (ph_id, Name, Value) 
	select @ph_id,	'Running', convert(varchar(23), login_time, 21) + '_' + convert(varchar(6), spid)
	from master..sysprocesses where spid = @@spid
--(MOD-030605)DPRCT b_id_end	declare btr_sp_cur cursor dynamic read_only for select sp_id, spid from btr_sysprocesses_tmp where b_id_end is null
	declare btr_sp_cur cursor dynamic read_only for select sp_id, spid from btr_sysprocesses_tmp	--(MOD-030605)DPRCT b_id_end
	open btr_sp_cur
	create table #dbcc_inbuf (
		EventType varchar(30),
		Parameters varchar(30),
		EventInfo varchar(300)
	)
	insert into btr_Params (ph_id, Name, Value) values (@ph_id, 'Delay', isnull(convert(nvarchar(100), @Delay, 21), '00:00:30'))
	insert into btr_Params (ph_id, Name, Value) values (@ph_id, 'ActionTrace', isnull(cast (@ActionTrace as nvarchar(255)), '1'))
	insert into btr_Params (ph_id, Name, Value) values (@ph_id, 'PreBlockCount', '0')
	insert into btr_Params (ph_id, Name, Value) values (@ph_id, 'ActionKill', isnull(cast (@ActionKill as nvarchar(255)),0))
	insert into btr_Params (ph_id, Name, Value) values (@ph_id, 'KillMSecs', isnull(cast (@KillMSecs as nvarchar(255)), '0'))
	insert into btr_Params (ph_id, Name, Value) values (@ph_id, 'KillCount', isnull(cast (@KillCount as nvarchar(255)), '0'))
	insert into btr_Params (ph_id, Name, Value) values (@ph_id, 'MaxCPU', isnull(cast (@MaxCPU as nvarchar(255)), '100'))
	insert into btr_Params (ph_id, Name, Value) values (@ph_id, 'SJHTraceFreq', isnull(cast (@SJHTraceFreq as nvarchar(255)), '10'))
	insert into btr_Params (ph_id, Name, Value) values (@ph_id, 'DoLockTrace', isnull(cast (@DoLockTrace as nvarchar(255)), '0'))

	insert into btr_Params (ph_id, Name, Value) values (@ph_id, 'ActionStop', '0')
	print 'usp_blocking_audit started on ' + cast (getdate() as nvarchar(255)) + ' with following parameters:'
	select * from btr_Params where ph_id = @ph_id
end else  begin
	PRINT 'Usage: usp_blocking_audit @Action = ''START''|''CONTROL''|''STOP''|''HELP''(''HELP'')'
	PRINT '				[, @Delay = time(00:00:30)]'
	PRINT '				[, @ActionTrace = 1|0(1)] '
	PRINT '				[, @ActionKill = 0|1(0)] '
	PRINT '				[, @KillMSecs  = nn(0)] '
	PRINT '				[, @KillCount  = nn(0)] '
	PRINT '				[, @MaxCPU  = nn(100)] '
	PRINT '				[, @SJHTraceFreq  = nn(10)] '
	PRINT '				[, @DoLockTrace  = 0|1(0)] '
	PRINT '@Action		- specifies action to perform; ''CONTROL'' allows to change other parameters without restarting trace'
	PRINT '@Delay		- delay between scans (each execution of trace batches) in time format'
	PRINT '@ActionTrace	- save snapshots from sysprocesses, syslocks and DBCC INPUTBUFFER'
	PRINT '@ActionKill	- kill culprit processes (processes which block other processes)'
	PRINT '@KillMSecs	- kill process if it blocks any other process for more than nn milliseconds. Deactivated when set to 0.'
	PRINT '@KillCount	- kill process if it blocks more than nn other processes. Deactivated when set to 0.'
	PRINT '@MaxCPU		- restricts BTR to nn milliseconds per second (100 = 10%) of machine CPU time'
	PRINT '@SJHTraceFreq 	- save sysjobhistory once per nn cycles of BTR execution. Deactivated at all when set to 0.'
	PRINT '@DoLockTrace 	- ommit saving syslockinfo if set to 0 (locks tracing is most space exigent).'
	return -1
end


/******************************* MAIN CYCLE *********************************/
declare @old_cpu int, @cur_cpu int,  @old_time datetime, @cur_time datetime

declare @last_sjhinst int, @nonsjh_count int
select @last_sjhinst = max(instance_id) from msdb.dbo.sysjobhistory
select @nonsjh_count = 0
WHILE (1 = 1) BEGIN
if (@debug = 1) begin
select Value from btr_Params where Name = 'Delay'
end
--protect CPU performance impact
		while  (1 =1) begin 
			select TOP 1 @ActionStop = cast (Value as bit) from btr_Params 
				where Name = 'ActionStop' order by ph_id desc
			if (@ActionStop  = 1) break 
			insert into btr_Batch (time_beg) values(default)
			select @b_id = @@IDENTITY
			select top 1 @MaxCPU = cast (Value as int) from btr_Params where Name = 'MaxCPU' order by ph_id desc 
			select top 1 @Delay = cast(Value as datetime) from btr_Params where Name = 'Delay' order by ph_id desc 
			waitfor delay @Delay
			select  @cur_cpu = cpu from master..sysprocesses where spid = @@spid
			select  @cur_time = getdate()
if (@debug = 1) select @cur_cpu, @old_cpu, @cur_time, @old_time
			if (isnull( 
				1000 * (@cur_cpu - @old_cpu) / datediff(ms, @old_time, @cur_time), @MaxCPU
				) > @MaxCPU) begin
					insert into btr_LOG(b_id, msg) values (
						@b_id, 'CPU Protection: WARNING - batch suppressed by CPU impact protection. ' 
						+ '1000 * ('+cast (@cur_cpu as varchar(10)) + ' - ' + isnull(cast (@old_cpu as varchar(10)), 'NULL') 
					+ ') / datediff(ms,' + isnull(convert (varchar (30), @old_time, 21), 'NULL') + ',' + convert (varchar (30), @cur_time, 21) + ') > ' 
					+ cast (@MaxCPU as varchar(10)) 
					)
			end else break
		end 
	select TOP 1 @ActionStop = cast (Value as bit) from btr_Params 
	where Name = 'ActionStop' order by ph_id desc
	if (@ActionStop  = 1) break 

	set @old_time = @cur_time
	set @old_cpu = @cur_cpu
	select TOP 1 @ActionTrace = cast (Value as bit) from btr_Params 
	where Name = 'ActionTrace' order by ph_id desc
	if (@ActionTrace  = 1) begin
		select TOP 1 @DoLockTrace = cast (Value as int) from btr_Params 
		where Name = 'DoLockTrace' order by ph_id desc 
		exec usp_blocking_trace @b_id = @b_id, @PreBlockCount = @PreBlockCount, @debug = @debug, @DoLockTrace = @DoLockTrace
	end
	if exists (	select * from btr_Params 
			where Name = 'ActionKill' and cast (Value as int) = 1) begin
		select TOP 1 @KillMSecs = cast (Value as int) from btr_Params where Name = 'KillMSecs'	order by ph_id desc 
		select TOP 1 @KillCount = cast (Value as int) from btr_Params where Name = 'KillCount'	order by ph_id desc 
		
		exec usp_blocking_kill @b_id = @b_id, @KillMSecs = @KillMSecs, @KillCount = @KillCount
	end
	select TOP 1 @SJHTraceFreq = cast (Value as int) from btr_Params where Name = 'SJHTraceFreq' order by ph_id desc 
	if (@SJHTraceFreq <> 0)	begin 
		if @SJHTraceFreq < @nonsjh_count or 
		(select max(instance_id) from msdb.dbo.sysjobhistory) - @last_sjhinst > 50 begin
			select @last_sjhinst = max(instance_id) from msdb.dbo.sysjobhistory
			select @nonsjh_count = 0
			exec usp_blocking_trace_sjh @b_id, @debug
		end else select @nonsjh_count = @nonsjh_count + 1
	end
	update btr_Batch set time_end = getdate() where b_id = @b_id
end
exec usp_blocking_tmp2base @b_id = @b_id, @PreBlockCount = @PreBlockCount, @AllRows = 1
select TOP 1 @SJHTraceFreq = cast (Value as int) from btr_Params where Name = 'SJHTraceFreq' order by ph_id desc 
if (@SJHTraceFreq <> 0)	exec usp_blocking_trace_sjh @b_id, @debug
close btr_sp_cur
deallocate btr_sp_cur
drop table #dbcc_inbuf
update btr_Params set Value = '-' + Value  where Name = 'Running'

select * from btr_Params
go


	