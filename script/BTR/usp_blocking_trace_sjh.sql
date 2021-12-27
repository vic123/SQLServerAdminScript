if exists (select * from sysobjects where name = 'usp_blocking_trace_sjh' and type = 'P')
drop procedure usp_blocking_trace_sjh
go
create procedure usp_blocking_trace_sjh (@b_id int, @debug int = 0) as begin
--	select @debug = 1
	declare @rcnt int, @err int
	select  instance_id, run_date, run_time, run_duration, run_status, cast(NULL as datetime) as time_beg, cast(NULL as datetime) as time_dur
		into #btr_sjh
		from msdb.dbo.sysjobhistory
	select @rcnt = @@ROWCOUNT, @err = @@ERROR	--(MOD-030612)
	if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'trace_sjh: ERROR ' + cast (@err as varchar(10)) + ' - when select into #btr_sjh')--(MOD-030612)
	update #btr_sjh set
		time_beg = convert (datetime, cast(run_date as varchar), 112) 
				+ convert (datetime, left (left('000000', 6 - len(cast (run_time as varchar))) + cast(run_time as varchar), 2) + ':' 
				+ substring(left('000000', 6 - len(cast (run_time as varchar))) + cast(run_time as varchar),3, 2) + ':' 
				+ right(left('000000', 6 - len(cast (run_time as varchar))) + cast(run_time as varchar), 2), 108),
		time_dur = convert (datetime, left (left('000000', 6 - len(cast (run_duration as varchar))) + cast(run_duration as varchar), 2) + ':' 
			+ substring(left('000000', 6 - len(cast (run_duration as varchar))) + cast(run_duration as varchar),3, 2) + ':' 
			+ right(left('000000', 6 - len(cast (run_duration as varchar))) + cast(run_duration as varchar), 2), 108)
	select @rcnt = @@ROWCOUNT, @err = @@ERROR	--(MOD-030612)
	if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'trace_sjh: ERROR ' + cast (@err as varchar(10)) + ' - when update #btr_sjh')	--(MOD-030612)
	if (@err  <> 0) begin	
		declare @stmnt varchar (4000)
		select @stmnt = 'select * into btr_sjh_dbg' + cast(@b_id as varchar) + ' from #btr_sjh'
		exec (@stmnt)
	end

	--optimization of btr_sysjobhistory join
	declare @min_iid int
	select @min_iid = min(instance_id) from #btr_sjh

	insert into btr_sysjobhistory (b_id, instance_id, job_id, step_id, step_name, sql_message_id, sql_severity, message, run_status, run_date, run_time, run_duration, operator_id_emailed, operator_id_netsent, operator_id_paged, retries_attempted, server)
	select btr_Batch.b_id, msjh.instance_id, job_id, step_id, step_name, sql_message_id, sql_severity, message, msjh.run_status, msjh.run_date, msjh.run_time, msjh.run_duration, operator_id_emailed, operator_id_netsent, operator_id_paged, retries_attempted, server
	from btr_Batch, msdb.dbo.sysjobhistory msjh join #btr_sjh sjht on 
		msjh.instance_id = sjht.instance_id
	where not exists 
		(select * from btr_sysjobhistory sjh where btr_Batch.b_id = sjh.b_id 
		and msjh.instance_id = sjh.instance_id and sjh.instance_id >= @min_iid)
	and sjht.time_beg < btr_Batch.time_end
	and (sjht.time_beg + sjht.time_dur > btr_Batch.time_beg
		or sjht.run_status = 4  --running
		)
	select @rcnt = @@ROWCOUNT, @err = @@ERROR	--(MOD-030612)
	if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'trace_sjh: ERROR ' + cast (@err as varchar(10)) + ' - when insert into btr_sysjobhistory')	--(MOD-030612)
end
go
		
