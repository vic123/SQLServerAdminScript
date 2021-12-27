if exists (select * from sysobjects where name = 'usp_blocking_trace' and type = 'P')
drop procedure usp_blocking_trace
go
create procedure usp_blocking_trace (@b_id int, @PreBlockCount int = 0, @debug bit = 0, @DoLockTrace bit = 0)  as begin
	declare @rcnt int, @err int
--(MOD-030605)DPRCT b_id_end	update btr_sysprocesses_tmp set b_id_end = @b_id - 1
--(MOD-030605)DPRCT b_id_end	select @rcnt = @@ROWCOUNT, @err = @@ERROR
--(MOD-030605)DPRCT b_id_endif (@debug = 1)	if (@rcnt <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ' + cast (@rcnt as varchar(10)) + ' processes has gone to history')
--(MOD-030605)DPRCT b_id_end	if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ERROR ' + cast (@err as varchar(10)) + ' - when processes has gone to history')

--(MOD-030605)DPRCT b_id_end	update btr_DBCCINB_tmp set b_id_end = @b_id - 1
--(MOD-030605)DPRCT b_id_end	from btr_sysprocesses_tmp btr_p
--(MOD-030605)DPRCT b_id_end	where btr_DBCCINB_tmp.sp_id = btr_p.sp_id
--(MOD-030605)DPRCT b_id_end	and btr_p.b_id_end is not null
--(MOD-030605)DPRCT b_id_end	select @rcnt = @@ROWCOUNT, @err = @@ERROR
--(MOD-030605)DPRCT b_id_endif (@debug = 1)	if (@rcnt <>0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ' + cast (@rcnt as varchar(10)) + ' dbcc input bufs has gone to history')
--(MOD-030605)DPRCT b_id_end	if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ERROR ' + cast (@err as varchar(10)) + ' - when dbcc input bufs has gone to history')

	if (@DoLockTrace = 1) begin
		update btr_syslockinfo_tmp set b_id_end = @b_id - 1
		where not exists (	select * from master..syslockinfo l
					where btr_syslockinfo_tmp.rsc_text = l.rsc_text and btr_syslockinfo_tmp.rsc_bin = l.rsc_bin and btr_syslockinfo_tmp.rsc_valblk = l.rsc_valblk and btr_syslockinfo_tmp.rsc_dbid = l.rsc_dbid and btr_syslockinfo_tmp.rsc_indid = l.rsc_indid and btr_syslockinfo_tmp.rsc_objid = l.rsc_objid and btr_syslockinfo_tmp.rsc_type = l.rsc_type and btr_syslockinfo_tmp.rsc_flag = l.rsc_flag and btr_syslockinfo_tmp.req_mode = l.req_mode and btr_syslockinfo_tmp.req_status = l.req_status and btr_syslockinfo_tmp.req_refcnt = l.req_refcnt and btr_syslockinfo_tmp.req_cryrefcnt = l.req_cryrefcnt and btr_syslockinfo_tmp.req_lifetime = l.req_lifetime and btr_syslockinfo_tmp.req_spid = l.req_spid and btr_syslockinfo_tmp.req_ecid = l.req_ecid and btr_syslockinfo_tmp.req_ownertype = l.req_ownertype and btr_syslockinfo_tmp.req_transactionID = l.req_transactionID and btr_syslockinfo_tmp.req_transactionUOW = l.req_transactionUOW)
		select @rcnt = @@ROWCOUNT, @err = @@ERROR
if (@debug = 1)	if (@rcnt<>0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ' + cast (@rcnt as varchar(10)) + ' locks has gone to history')
		if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ERROR ' + cast (@err as varchar(10)) + ' - when locks has gone to history')
	end

--insert into tmp those processes that has relationship to blocks
--(MOD-030605)DPRCT b_id_end	insert into btr_sysprocesses_tmp (b_id_beg, spid, kpid, blocked, waittype, waittime, lastwaittype, waitresource, dbid, uid, cpu, physical_io, memusage, login_time, last_batch, ecid, open_tran, status, sid, hostname, program_name, hostprocess, cmd, nt_domain, nt_username, net_address, net_library, loginame, context_info)
--(MOD-030612)debug_sp beg
	declare btr_sp_dbg_cur cursor for select spid, cpu, login_time from master..sysprocesses
	declare @dbg_spid int, @dbg_cpu int, @dbg_login_time datetime
	open btr_sp_dbg_cur
	while (1 = 1) begin
		fetch next from btr_sp_dbg_cur into @dbg_spid, @dbg_cpu, @dbg_login_time 
		if (@@fetch_status <> 0) break
		insert into btr_sysprocessesCur_debug (b_id, spid, cpu, login_time) values (@b_id, @dbg_spid, @dbg_cpu, @dbg_login_time)
	end
	close btr_sp_dbg_cur
	deallocate btr_sp_dbg_cur
	insert into btr_sysprocessesIns_debug (b_id, spid, cpu, login_time) 
	select @b_id, spid, cpu, login_time from master..sysprocesses
	insert into btr_sysprocessesCnt_debug (b_id, spid, Cnt) 
	select @b_id, spid, count(spid) from master..sysprocesses
	group by spid
--(MOD-030612)debug_sp end	
	insert into btr_sysprocesses_tmp (b_id_beg, b_id_end, spid, kpid, blocked, waittype, waittime, lastwaittype, waitresource, dbid, uid, cpu, physical_io, memusage, login_time, last_batch, ecid, open_tran, status, sid, hostname, program_name, hostprocess, cmd, nt_domain, nt_username, net_address, net_library, loginame, context_info) --(MOD-030605)DPRCT b_id_end
--(MOD-030605)DPRCT b_id_end	select @b_id, spid, kpid, blocked, waittype, waittime, lastwaittype, waitresource, dbid, uid, cpu, physical_io, memusage, login_time, last_batch, ecid, open_tran, status, sid, hostname, program_name, hostprocess, cmd, nt_domain, nt_username, net_address, net_library, loginame, context_info
	select @b_id, @b_id, spid, kpid, blocked, waittype, waittime, lastwaittype, waitresource, dbid, uid, cpu, physical_io, memusage, login_time, last_batch, ecid, open_tran, status, sid, hostname, program_name, hostprocess, cmd, nt_domain, nt_username, net_address, net_library, loginame, context_info --(MOD-030605)DPRCT b_id_end
	from master..sysprocesses main_p
--(MOD-030605)DPRCT b_id_end	where not exists (	select * from btr_sysprocesses_tmp btr_p
--(MOD-030605)DPRCT b_id_end				where main_p.spid = btr_p.spid and main_p.kpid = btr_p.kpid and main_p.blocked = btr_p.blocked and main_p.waittype = btr_p.waittype and main_p.waittime = btr_p.waittime and main_p.lastwaittype = btr_p.lastwaittype and main_p.waitresource = btr_p.waitresource and main_p.dbid = btr_p.dbid and main_p.uid = btr_p.uid and main_p.cpu = btr_p.cpu and main_p.physical_io = btr_p.physical_io and main_p.memusage = btr_p.memusage and main_p.login_time = btr_p.login_time and main_p.last_batch = btr_p.last_batch and main_p.ecid = btr_p.ecid and main_p.open_tran = btr_p.open_tran and main_p.status = btr_p.status and main_p.sid = btr_p.sid and main_p.hostname = btr_p.hostname and main_p.program_name = btr_p.program_name and main_p.hostprocess = btr_p.hostprocess and main_p.cmd = btr_p.cmd and main_p.nt_domain = btr_p.nt_domain and main_p.nt_username = btr_p.nt_username and main_p.net_address = btr_p.net_address and main_p.net_library = btr_p.net_library and main_p.loginame = btr_p.loginame and main_p.context_info = btr_p.context_info)
--(MOD-030605)DPRCT b_id_end	and (	blocked > -@PreBlockCount
	where (	blocked > -@PreBlockCount	--(MOD-030605)DPRCT b_id_end
		or exists (select * from master..sysprocesses p1 where main_p.spid = p1.blocked)
	)
	select @rcnt = @@ROWCOUNT, @err = @@ERROR
if (@debug = 1)	if (@rcnt<>0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ' + cast (@rcnt as varchar(10)) + ' processes appeared/mutated')
	if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ERROR ' + cast (@err as varchar(10)) + ' - when processes appeared/mutated')
if (@DoLockTrace = 1) begin
--insert into tmp those locks that changed/appeared 	
	insert into btr_syslockinfo_tmp (b_id_beg, rsc_text, rsc_bin, rsc_valblk, rsc_dbid, rsc_indid, rsc_objid, rsc_type, rsc_flag, req_mode, req_status, req_refcnt, req_cryrefcnt, req_lifetime, req_spid, req_ecid, req_ownertype, req_transactionID, req_transactionUOW)
	select @b_id, rsc_text, rsc_bin, rsc_valblk, rsc_dbid, rsc_indid, rsc_objid, rsc_type, rsc_flag, req_mode, req_status, req_refcnt, req_cryrefcnt, req_lifetime, req_spid, req_ecid, req_ownertype, req_transactionID, req_transactionUOW
	from master..syslockinfo main_l
	where not exists (	select * from btr_syslockinfo_tmp btr_l
				where main_l.rsc_text = btr_l.rsc_text and main_l.rsc_bin = btr_l.rsc_bin and main_l.rsc_valblk = btr_l.rsc_valblk and main_l.rsc_dbid = btr_l.rsc_dbid and main_l.rsc_indid = btr_l.rsc_indid and main_l.rsc_objid = btr_l.rsc_objid and main_l.rsc_type = btr_l.rsc_type and main_l.rsc_flag = btr_l.rsc_flag and main_l.req_mode = btr_l.req_mode and main_l.req_status = btr_l.req_status and main_l.req_refcnt = btr_l.req_refcnt and main_l.req_cryrefcnt = btr_l.req_cryrefcnt and main_l.req_lifetime = btr_l.req_lifetime and main_l.req_spid = btr_l.req_spid and main_l.req_ecid = btr_l.req_ecid and main_l.req_ownertype = btr_l.req_ownertype and main_l.req_transactionID = btr_l.req_transactionID and main_l.req_transactionUOW = btr_l.req_transactionUOW)
	and exists (select * from btr_sysprocesses_tmp where spid = main_l.req_spid)
	select @rcnt = @@ROWCOUNT, @err = @@ERROR
if (@debug = 1)	if (@rcnt <>0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ' + cast (@rcnt as varchar(10)) + ' locks appeared/mutated')	
	if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ERROR ' + cast (@err as varchar(10)) + ' - when locks appeared/mutated')
end
--(MOD-030605)DPRCT b_id_end - (moved here from usp_blocking_tmp2base) - beg
if (@debug = 1) select sp_id, spid, b_id_beg, kpid, b_id_end, blocked, waittype, waittime, lastwaittype, waitresource, dbid, uid, cpu, physical_io, memusage, login_time, last_batch, ecid, open_tran, status, sid, hostname, program_name, hostprocess, cmd, nt_domain, nt_username, net_address, net_library, loginame, context_info
from btr_sysprocesses_tmp --(MOD-030605)DPRCT b_id_endwhere b_id_end is not null or @AllRows = 1
	insert into btr_sysprocesses (sp_id, spid, b_id_beg, kpid, b_id_end, blocked, waittype, waittime, lastwaittype, waitresource, dbid, uid, cpu, physical_io, memusage, login_time, last_batch, ecid, open_tran, status, sid, hostname, program_name, hostprocess, cmd, nt_domain, nt_username, net_address, net_library, loginame, context_info)
	select sp_id, spid, b_id_beg, kpid, b_id_end, blocked, waittype, waittime, lastwaittype, waitresource, dbid, uid, cpu, physical_io, memusage, login_time, last_batch, ecid, open_tran, status, sid, hostname, program_name, hostprocess, cmd, nt_domain, nt_username, net_address, net_library, loginame, context_info
	from btr_sysprocesses_tmp
--(MOD-030605)DPRCT b_id_end	where b_id_end is not null or @AllRows = 1
	select @rcnt = @@ROWCOUNT, @err = @@ERROR
if (@debug = 1) if (@rcnt <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TMP2BASE: ' + cast (@rcnt as varchar(10)) + ' processes appended to history')
	if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TMP2BASE: ERROR ' + cast (@err as varchar(10)) + ' - when processes appended to history')
--(MOD-030605)DPRCT b_id_end - (moved here from usp_blocking_tmp2base) - end

--read dbcc input buffer for each selcted process
--delete pre buffered non-blocked yet process history
	declare @sp_id int, @spid int  
	declare @dbccstmt varchar(200)
        fetch first from btr_sp_cur into @sp_id, @spid 
	while ( @@fetch_status = 0 ) begin
		set @dbccstmt = 'dbcc inputbuffer ('+convert(char(5),@spid)+')'
		insert  into #dbcc_inbuf  exec (@dbccstmt)
--(MOD-030605)DPRCT b_id_end		if not exists (	select * from btr_DBCCINB_tmp d, #dbcc_inbuf
--(MOD-030605)DPRCT b_id_end				where @sp_id = d.sp_id and #dbcc_inbuf.EventType = d.EventType and #dbcc_inbuf.Parameters = d.Parameters and #dbcc_inbuf.EventInfo = d.EventInfo) begin
--(MOD-030605)DPRCT b_id_end			update btr_DBCCINB_tmp set b_id_end = @b_id - 1 where sp_id = @sp_id
--(MOD-030605)DPRCT b_id_end			select @rcnt = @@ROWCOUNT, @err = @@ERROR
--(MOD-030605)DPRCT b_id_endif (@debug = 1)	if (@rcnt<>0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ' + cast (@rcnt as varchar(10)) + ' dbcc input buf(s) has gone to history')
--(MOD-030605)DPRCT b_id_end			if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ERROR ' + cast (@err as varchar(10)) + ' - when input buf(s) has gone to history')
--(MOD-030605)DPRCT b_id_end			insert into btr_DBCCINB_tmp (sp_id, b_id_beg, EventType, Parameters, EventInfo)
			insert into btr_DBCCINB (sp_id, b_id_beg, b_id_end, EventType, Parameters, EventInfo)
--(MOD-030605)DPRCT b_id_end			select @sp_id, @b_id, EventType, Parameters, EventInfo
			select @sp_id, @b_id, @b_id, EventType, Parameters, EventInfo
			from #dbcc_inbuf
			select @rcnt = @@ROWCOUNT, @err = @@ERROR
if (@debug = 1)	if (@rcnt<>0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ' + cast (@rcnt as varchar(10)) + ' dbcc input buf(s) appeared/mutated')
			if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TRACE: ERROR ' + cast (@err as varchar(10)) + ' - when dbcc input buf(s) appeared/mutated')
--(MOD-030605)DPRCT b_id_end		end
		truncate table #dbcc_inbuf
	        fetch next from btr_sp_cur into @sp_id, @spid 
	end
	delete from btr_sysprocesses_tmp --(MOD-030605)DPRCT b_id_end where b_id_end is not null or @AllRows = 1	--(MOD-030605)DPRCT b_id_end - moved here from usp_blocking_tmp2base - beg
	exec usp_blocking_tmp2base @b_id = @b_id, @PreBlockCount = @PreBlockCount, @AllRows = 0, @debug = @debug
end
go
		
