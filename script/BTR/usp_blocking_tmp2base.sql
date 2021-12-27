if exists (select * from sysobjects where name = 'usp_blocking_tmp2base' and type = 'P')
drop procedure usp_blocking_tmp2base
go
create procedure usp_blocking_tmp2base (@b_id int, @PreBlockCount int = 0, @AllRows bit = 0, @debug bit = 0)  as 
	declare @rcnt int, @err int
--select @debug = 0
--(MOD-030605)DPRCT b_id_end (moved to usp_blocking_trace)if (@debug = 1) select sp_id, spid, b_id_beg, kpid, b_id_end, blocked, waittype, waittime, lastwaittype, waitresource, dbid, uid, cpu, physical_io, memusage, login_time, last_batch, ecid, open_tran, status, sid, hostname, program_name, hostprocess, cmd, nt_domain, nt_username, net_address, net_library, loginame, context_info
--(MOD-030605)DPRCT b_id_end (moved to usp_blocking_trace)from btr_sysprocesses_tmp --(MOD-030605)DPRCT b_id_endwhere b_id_end is not null or @AllRows = 1
--(MOD-030605)DPRCT b_id_end (moved to usp_blocking_trace)	insert into btr_sysprocesses (sp_id, spid, b_id_beg, kpid, b_id_end, blocked, waittype, waittime, lastwaittype, waitresource, dbid, uid, cpu, physical_io, memusage, login_time, last_batch, ecid, open_tran, status, sid, hostname, program_name, hostprocess, cmd, nt_domain, nt_username, net_address, net_library, loginame, context_info)
--(MOD-030605)DPRCT b_id_end (moved to usp_blocking_trace)	select sp_id, spid, b_id_beg, kpid, b_id_end, blocked, waittype, waittime, lastwaittype, waitresource, dbid, uid, cpu, physical_io, memusage, login_time, last_batch, ecid, open_tran, status, sid, hostname, program_name, hostprocess, cmd, nt_domain, nt_username, net_address, net_library, loginame, context_info
--(MOD-030605)DPRCT b_id_end (moved to usp_blocking_trace)	from btr_sysprocesses_tmp
--(MOD-030605)DPRCT b_id_end	where b_id_end is not null or @AllRows = 1
--(MOD-030605)DPRCT b_id_end (moved to usp_blocking_trace)	select @rcnt = @@ROWCOUNT, @err = @@ERROR
--(MOD-030605)DPRCT b_id_end (moved to usp_blocking_trace)if (@debug = 1) if (@rcnt <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TMP2BASE: ' + cast (@rcnt as varchar(10)) + ' processes appended to history')
--(MOD-030605)DPRCT b_id_end (moved to usp_blocking_trace)	if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TMP2BASE: ERROR ' + cast (@err as varchar(10)) + ' - when processes appended to history')
--(MOD-030605)DPRCT b_id_endif (@debug = 1) 	select dbccinb_id, sp_id, b_id_beg, b_id_end, EventType, Parameters, EventInfo
--(MOD-030605)DPRCT b_id_endfrom btr_DBCCINB_tmp where b_id_end is not null or @AllRows = 1
--(MOD-030605)DPRCT b_id_end	insert into btr_DBCCINB (dbccinb_id, sp_id, b_id_beg, b_id_end, EventType, Parameters, EventInfo)
--(MOD-030605)DPRCT b_id_end	select dbccinb_id, sp_id, b_id_beg, b_id_end, EventType, Parameters, EventInfo
--(MOD-030605)DPRCT b_id_end	from btr_DBCCINB_tmp
--(MOD-030605)DPRCT b_id_end	where b_id_end is not null or @AllRows = 1
--(MOD-030605)DPRCT b_id_end	select @rcnt = @@ROWCOUNT, @err = @@ERROR
--(MOD-030605)DPRCT b_id_endif (@debug = 1) if (@rcnt <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TMP2BASE: ' + cast (@rcnt as varchar(10)) + ' dbcc infos appended to history')
--(MOD-030605)DPRCT b_id_end	if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TMP2BASE: ERROR ' + cast (@err as varchar(10)) + ' - when dbcc infos appended to history')
--(MOD-030605)DPRCT b_id_end	delete from btr_DBCCINB_tmp where b_id_end is not null or @AllRows = 1

	insert into btr_syslockinfo (sl_id, rsc_text, b_id_beg, rsc_bin, b_id_end, rsc_valblk, rsc_dbid, rsc_indid, rsc_objid, rsc_type, rsc_flag, req_mode, req_status, req_refcnt, req_cryrefcnt, req_lifetime, req_spid, req_ecid, req_ownertype, req_transactionID, req_transactionUOW)
	select sl_id, rsc_text, b_id_beg, rsc_bin, b_id_end, rsc_valblk, rsc_dbid, rsc_indid, rsc_objid, rsc_type, rsc_flag, req_mode, req_status, req_refcnt, req_cryrefcnt, req_lifetime, req_spid, req_ecid, req_ownertype, req_transactionID, req_transactionUOW
	from btr_syslockinfo_tmp
	where b_id_end is not null or @AllRows = 1
	select @rcnt = @@ROWCOUNT, @err = @@ERROR
if (@debug = 1) if (@rcnt <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TMP2BASE: ' + cast (@rcnt as varchar(10)) + ' locks appended to history')
	if (@err <> 0) insert into btr_LOG(b_id, msg) values (@b_id, 'TMP2BASE: ERROR ' + cast (@err as varchar(10)) + ' - when locks appended to history')
	delete from btr_syslockinfo_tmp where b_id_end is not null or @AllRows = 1

--(MOD-030605)DPRCT b_id_end (moved to usp_blocking_trace)	delete from btr_sysprocesses_tmp --(MOD-030605)DPRCT b_id_end where b_id_end is not null or @AllRows = 1
go



