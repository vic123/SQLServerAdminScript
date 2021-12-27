if exists (select * from sysobjects where name = 'usp_blocking_report' and type = 'P')
drop procedure usp_blocking_report
go
create procedure usp_blocking_report (@spid int = NULL, 
					@beg datetime = NULL, 
					@end datetime  = NULL,
					@in_brief bit = 0,
					@MinWaitT int = 0,	--minimum process waittime. 0 - disabled
					@ShowEmptyBatch bit = 0	--determine whether to report execution of a batch 
								--that did not register any blocks
					) as begin 
	set nocount on
	declare @bid int, @b_title varchar(200), 
					@time_beg datetime, @time_end datetime 
	declare @spid_loc int
	declare @debug int
	set @debug = 0 

	if @beg is null select @beg = min(time_beg) from btr_Batch
	if @end is null select @end = max(time_end) from btr_Batch

	declare btr_Batch_cur cursor for select b_id 
		from btr_Batch 
		where time_beg >= @beg and time_end <= @end order by time_beg, time_end
	open btr_Batch_cur
	fetch next from  btr_Batch_cur into @bid
	while ( @@fetch_status = 0 ) begin
--(MOD-030605)DPRCT b_id_end		if (@@fetch_status <> 0) break
		select @b_title = '************** BATCH ' + cast (@bid as varchar(10)) + ' **************************************************'	
if (@debug = 1) select spid from btr_sysprocesses where spid = isnull(@spid, spid) and @bid between b_id_beg and b_id_end and isnull(waittime,0) >= isnull(@MinWaitT, isnull(waittime,0))
		declare btr_sp_cur cursor for select spid from btr_sysprocesses 
			where spid = isnull(@spid, spid) and @bid between b_id_beg and b_id_end
			and isnull(waittime,0) >= isnull(@MinWaitT, isnull(waittime,0))
		open btr_sp_cur
		fetch next from  btr_sp_cur into @spid_loc
if (@debug = 2) select @@fetch_status, @ShowEmptyBatch 
		if (@@fetch_status = 0) or (@ShowEmptyBatch = 1) begin
			select @b_title
			if ( exists (select * from btr_sysjobhistory sjh where b_id = @bid)
			) begin
				select 'SYSJOBS THAT RUN AT THE TIME OF THE BATCH ' + + cast (@bid as varchar) 
				select sjh.instance_id,  
					sjh.Server + '.' + sl.name + '.' + sj.name + '-' + cast (sjh.step_id as varchar(10)) + '.' + sjh.step_name 
					+ cast (sjh.run_status as varchar(10)) + '_' 
					+ cast (sjh.run_date as varchar(10)) + '-' + cast (sjh.run_time as varchar(10)) + '_' 
					+ cast (sjh.run_duration as varchar(10)) + '_' 
					+ sjh.Message collate database_default
					as [Server.Owner.Job-N.Step_Status_YYYYMMDD-HHMMSS(start)_HHMMSS(dur)_Message] 
					from btr_sysjobhistory sjh 
					left outer join msdb.dbo.sysjobs sj on sjh.job_id = sj.job_id
					left outer join master.dbo.syslogins sl on sj.owner_sid = sl.sid
				where sjh.b_id = @bid
			end
		end
		if (@@fetch_status <> 0 and @ShowEmptyBatch = 1) begin 
			select * from btr_Batch where b_id = @bid
			select 'NO BLOCKED/BLOCKING PROCESSES MEETING FILTERING CONDITIONS'
		end
		while ( @@fetch_status = 0 ) begin
			select * from btr_Batch where b_id = @bid
			exec usp_blocking_1batchshow @spid_loc, @bid, '', @in_brief, 0, @debug
			fetch next from  btr_sp_cur into @spid_loc
		end
		close btr_sp_cur		
		deallocate btr_sp_cur		
		fetch next from  btr_Batch_cur into @bid
	end
	close btr_Batch_cur
	deallocate btr_Batch_cur
end
go
	

if exists (select * from sysobjects where name = 'usp_blocking_1batchshow' and type = 'P')
drop procedure usp_blocking_1batchshow
go
create procedure usp_blocking_1batchshow (@spid int, @bid int, 
						@indent varchar(900) = '',
						@in_brief bit,
						@btr_nestlevel int = 0,
						@debug int = 0) as begin
	declare @pcss varchar(900), @newindent varchar(900)
	declare @blocker int, @sp_id int, @sl_id int
	declare @dbname sysname, @dbname_prn sysname
	declare @estr nvarchar (4000)
		
	select @pcss = @indent + 'PROCESS ' + cast (@spid as varchar(30))
	select @pcss + ' :' 
--(MOD-030605)DPRCT b_id_end	declare btr_spmy_cur cursor for select sp_id from btr_sysprocesses where @bid between b_id_beg and b_id_end and spid = @spid
--(MOD-030605)DPRCT b_id_end	open btr_spmy_cur
--(MOD-030605)DPRCT b_id_end	while (1 = 1) begin
--(MOD-030605)DPRCT b_id_end		fetch next from  btr_spmy_cur into @sp_id
--(MOD-030605)DPRCT b_id_end		if @@fetch_status <> 0 break
		select @sp_id = sp_id from btr_sysprocesses where @bid = b_id_beg and spid = @spid --(MOD-030605)DPRCT b_id_end
		
		select @dbname_prn = isnull(name, 'NULL'), @dbname = isnull(name, 'master')
		from btr_sysprocesses bsp left outer join master.dbo.sysdatabases sd on bsp.dbid = sd.dbid
--(MOD-030605)DPRCT b_id_end		where @bid between b_id_beg and b_id_end and spid = @spid
		where sp_id = @sp_id	--(MOD-030605)DPRCT b_id_end
		select @estr = 'select sp_id, spid, ''' + @dbname_prn + '.'' + isnull(su.name, ''NULL'') + ''_'' + ' 
			+ 'cast (blocked as varchar(10)) + ''_'' + ' 
			+ 'cast (waittime as varchar(10)) + ''_'' + ' 
			+ 'ltrim(rtrim(lastwaittype)) + ''_'' + '
			+ 'cast (open_tran as varchar(10)) COLLATE database_default ' 
			+ 'as [DB.user_Blocked_WaitTime_LastWaitType_OpenTran], '
			+ 'cmd, kpid, waittype, waitresource, '
			+ 'cpu, physical_io, memusage, loginame, login_time, last_batch, ecid, open_tran, bsp.status, bsp.sid, hostname, program_name, hostprocess, nt_domain, nt_username, net_address, net_library, context_info '
			+ 'from btr_sysprocesses bsp left outer join ' + @dbname + '.dbo.sysusers su on bsp.uid = su.uid '
--(MOD-030606)DPRCT b_id_end			+ 'where ' + cast (@bid as varchar(10)) + ' between b_id_beg and b_id_end and spid = ' + cast (@spid as varchar(10))
			+ 'where sp_id = ' + cast (@sp_id as varchar(10))	--(MOD-030606)DPRCT b_id_end
		if (@debug  = 2) select @estr
		exec (@estr)
		if (@btr_nestlevel = 0 or @in_brief = 0) begin
			select @pcss + ' DBCC INPUTBUFFER'
			select dbccinb_id, EventType, Parameters, EventInfo from btr_DBCCINB d 
			where d.sp_id = @sp_id
		end
--(MOD-030605)DPRCT b_id_end	end
--(MOD-030605)DPRCT b_id_end	close btr_spmy_cur
--(MOD-030605)DPRCT b_id_end	deallocate btr_spmy_cur
	if (@btr_nestlevel = 0 or @in_brief = 0) begin
		select @pcss + ' LOCKS'
		create table #pcss_sl (	sl_id                int,
					[DB.Object.Index_RCSType_ReqStatus_RecOwnerType_ReqMode] nvarchar(3000),
					rsc_text             nchar(32) NOT NULL,
					rsc_bin              binary(16) NOT NULL,
					rsc_valblk           binary(16) NOT NULL,
					rsc_flag             tinyint NOT NULL,
					req_refcnt           smallint NOT NULL,
					req_cryrefcnt        smallint NOT NULL,
					req_lifetime         int NOT NULL,
					req_spid             int NOT NULL,
					req_ecid             int NOT NULL,
					req_transactionID    bigint NULL,
					req_transactionUOW   uniqueidentifier NULL )
		declare btr_slmy_cur cursor for select sl_id from btr_syslockinfo where @bid between b_id_beg and b_id_end and req_spid = @spid
		open btr_slmy_cur
		while (1 = 1) begin
			fetch next from  btr_slmy_cur into @sl_id
			if @@fetch_status <> 0 break
			select @dbname_prn = isnull(name, 'NULL'), @dbname = isnull(name, 'master')
			from btr_syslockinfo bsl left outer join master.dbo.sysdatabases sd on bsl.rsc_dbid = sd.dbid
			where bsl.sl_id = @sl_id

			select @estr = 	'insert into #pcss_sl (sl_id, [DB.Object.Index_RCSType_ReqStatus_RecOwnerType_ReqMode], '
				+	'rsc_text, rsc_bin, rsc_valblk, ' 
				+ 	'rsc_flag, req_refcnt, req_cryrefcnt, req_lifetime, req_spid, req_ecid, req_transactionID, req_transactionUOW ) '
				+ 	'select sl_id, ''' + @dbname_prn + '.'' + isnull(so.name, ''NULL'') + ''.'' + isnull(si.name, ''NULL'') + ''_'' + ' 
				+ 'CASE rsc_type '
				+ 'WHEN 1 THEN ''NULL Resource'' '
				+ 'WHEN 2 THEN ''Database'' '
				+ 'WHEN 3 THEN ''File'' '
				+ 'WHEN 4 THEN ''Index'' '
				+ 'WHEN 5 THEN ''Table'' '
				+ 'WHEN 6 THEN ''Page'' '
				+ 'WHEN 7 THEN ''Key'' '
				+ 'WHEN 8 THEN ''Extent'' '
				+ 'WHEN 9 THEN ''Row ID'' '
				+ 'WHEN 10 THEN ''Application'' '
				+ 'END + ''_'' + '
				+ 'CASE req_status '
				+ 'WHEN 1 THEN ''Granted'' '
				+ 'WHEN 2 THEN ''Converting'' '
				+ 'WHEN 3 THEN ''Waiting'' '
				+ 'END + ''_'' + '
				+ 'CASE req_OwnerType '
				+ 'WHEN 1 THEN ''Transaction'' '
				+ 'WHEN 2 THEN ''Cursor'' '
				+ 'WHEN 3 THEN ''Session'' '
				+ 'WHEN 4 THEN ''ExSession'' '
				+ 'END + ''_'' + '
				+ 'CASE req_mode '
				+ 'WHEN 0 THEN ''No access is granted'' '
				+ 'WHEN 1 THEN ''Schema stability'' '
				+ 'WHEN 2 THEN ''Schema modification'' '
				+ 'WHEN 3 THEN ''Shared'' '
				+ 'WHEN 4 THEN ''Update'' '
				+ 'WHEN 5 THEN ''Exclusive'' '
				+ 'WHEN 6 THEN ''Intent Shared'' '
				+ 'WHEN 7 THEN ''Intent Update'' '
				+ 'WHEN 8 THEN ''Intent Exclusive'' '
				+ 'WHEN 9 THEN ''Shared Intent Update'' '
				+ 'WHEN 10 THEN ''Shared Intent Exclusive'' '
				+ 'WHEN 11 THEN ''Update Intent Exclusive'' '
				+ 'WHEN 12 THEN ''bulk operations'' '
				+ 'WHEN 13 THEN ''serializable range scan'' '
				+ 'WHEN 14 THEN ''serializable update scan'' '
				+ 'WHEN 15 THEN ''Insert Key-Range and Null Resource lock'' '
				+ 'WHEN 16 THEN ''Range Conversion lock, RangeI_N and S'' '
				+ 'WHEN 17 THEN ''Range Conversion lock, RangeI_N and U'' '
				+ 'WHEN 18 THEN ''Range Conversion lock, RangeI_N and X'' '
				+ 'WHEN 19 THEN ''Range Conversion lock, RangeI_N and RangeS_S'' '
				+ 'WHEN 20 THEN ''Key-Range Conversion lock, RangeI_N and RangeS_U'' '
				+ 'WHEN 21 THEN ''Exclusive Key-Range and Exclusive Resource lock'' '
				+ 'END '
				+ 'as [DB.Object.Index_RCSType_ReqStatus_RecOwnerType_ReqMode] , '
				+ 'rsc_text, rsc_bin, rsc_valblk, ' 
				+ 'rsc_flag, req_refcnt, req_cryrefcnt, req_lifetime, req_spid, req_ecid, req_transactionID, req_transactionUOW '
				+ 'from btr_syslockinfo bsl left outer join ' + @dbname + '.dbo.sysindexes si on rsc_indid = si.indid and rsc_objid = si.id ' 
				+ 'left outer join ' + @dbname + '.dbo.sysobjects so on bsl.rsc_objid = so.id '
				+ 'where bsl.sl_id = ' + cast (@sl_id as varchar(10))
			if (@debug =2) select @estr
			exec (@estr)
		end
		declare @desc_len int
		select @desc_len = max(len([DB.Object.Index_RCSType_ReqStatus_RecOwnerType_ReqMode])) from #pcss_sl
		select @estr = 'alter table #pcss_sl alter column [DB.Object.Index_RCSType_ReqStatus_RecOwnerType_ReqMode] nvarchar('+ convert(varchar, @desc_len) + ')'
		if (@debug =2) select @estr
		exec (@estr)
		select * from #pcss_sl
		drop table #pcss_sl
		close btr_slmy_cur
		deallocate btr_slmy_cur
	end
	select @blocker = NULL
	select @blocker = blocked from btr_sysprocesses where @bid between b_id_beg and b_id_end and spid = @spid and blocked <> 0
	select @newindent = '[' + @pcss + ' BLOCKER] '
	select @btr_nestlevel = @btr_nestlevel + 1
	if (@blocker is null) select @pcss + ' BLOCKER: NONE'
	else 	if (@@NESTLEVEL > 30) select @pcss + ' BLOCKER: CONTINUED...(DEADLOCK SUSPICION)'
		else exec usp_blocking_1batchshow @blocker, @bid, @newindent, @in_brief, @btr_nestlevel, @debug 
end
go




