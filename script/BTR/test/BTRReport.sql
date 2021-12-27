--************************************************************************************************************ 
--************ Output structure of usp_blocking_report 
--************************************************************************************************************ 
	--BTR Batch header - logging time interval of displayed data
	--Process general info from sysprocesses table
	--Process INPUTBUFFER returned by DBCC command
	--Process locks info from syslockinfo table
	--Process blocker (if any) - general info, [INPUTBUFFER, locks] for all blockers in recursive manner


--************************************************************************************************************ 
--************ Display full output for some time period
--************************************************************************************************************ 
--To retrieve BTR activity time frame run
--select min(time_beg), max(time_beg) from btr_batch

exec usp_blocking_report @beg = '2003-02-16 00:42:35', @end = '2003-02-16 00:42:40', @ShowEmptyBatch = 1


--************************************************************************************************************ 
--************ Display brief output for processes with long waiting times
--************************************************************************************************************ 
--To retrieve maximum process waittime run
--select max(waittime) from btr_sysprocesses
exec usp_blocking_report @in_brief = 1, @MinWaitT = 5000


--************************************************************************************************************ 
--************ Display brief output for particular process
--************************************************************************************************************ 
--To retrieve identifiers of logged processes run
--select distinct spid from btr_sysprocesses order by spid 
exec usp_blocking_report @spid = 59, @in_brief = 1


--************************************************************************************************************ 
--************ ADVANCED SECTION
--************************************************************************************************************ 
--1. Which SPID is the main CULPRIT in the chain of blockers and blockees? 
--(one may block another, the blocked one may block the third one, etc.)
--2. What SQL Statements were running around that time 
--(value from INPUTBUFFER, which should be recorded more than once per each SPID 
--(either parent, or child), because DBCC INPUTBUFFER MAY CHANGE EVERY SECOND as you run it.
--3. What was the exact CHAIN of blocker-blockees.

drop table #blockee_blocker
drop table #sp_pool
set nocount on

declare @beg datetime, @end datetime
--select min(time_beg), max(time_beg) from btr_batch
select @beg  = '2003-02-21 02:25:34.840', @end = '2003-02-21 02:25:50.583'
select b_id, spid, blocked into #sp_pool  
from btr_sysprocesses join btr_batch 
	on b_id between b_id_beg and b_id_end
where btr_batch.time_beg >= @beg and time_end <= @end 
group by b_id, spid, blocked

select b.b_id, cast (spid as varchar) as chain, blocked as blocker, 
		spid as blockee, 0 as level, 0 as length into #blockee_blocker
from #sp_pool sp join btr_batch b
	on sp.b_id = b.b_id
where isnull(blocked,0) = 0	--deadlock situation is ignored - it is handled by SQL Server
group by b.b_id, spid, blocked


while exists (select * from #sp_pool 
		where not exists (select * from #blockee_blocker bb 
					where bb.blockee = #sp_pool.spid and bb.b_id = #sp_pool.b_id)
		and exists (select * from #blockee_blocker bb --deadlock situation is ignored 
					where bb.blockee = #sp_pool.blocked and bb.b_id = #sp_pool.b_id)
	) begin
	insert into #blockee_blocker (b_id, chain, blocker, blockee, level, length)
	select bb.b_id, cast (bb.blockee as varchar) + '.' + cast(spp.spid as varchar), bb.blockee, spp.spid, 
		bb.level + 1 as level, 1 as length
	from #sp_pool spp join #blockee_blocker bb on spp.blocked = bb.blockee and spp.b_id = bb.b_id
	delete #sp_pool 
	where exists (select * from  #blockee_blocker bb 
			where #sp_pool.spid = bb.blockee and #sp_pool.b_id = bb.b_id)

	insert into #blockee_blocker (b_id, chain,  blocker, blockee, level, length)
	select bb_blocker.b_id, bb_blocker.chain + '.' + cast(bb_blockee.blockee as varchar),
	 bb_blocker.blocker, bb_blockee.blockee, bb_blocker.level + 1, bb_blocker.length + 1
	from #blockee_blocker bb_blocker join #blockee_blocker bb_blockee 
		on bb_blocker.blockee =  bb_blockee.blocker and  bb_blocker.b_id = bb_blockee.b_id
	where bb_blocker.blocker <> 0
end
--select * from #blockee_blocker order by b_id, blocker, level, blockee
select 'ONLY DEADLOCKED SPs MAY LEFT HERE'
select * from #sp_pool
select 'LONGEST BLOCK CHAINS'
select * from #blockee_blocker bb
where not exists (select * from #blockee_blocker bb1 
		where --bb.b_id = bb1.b_id--		and bb.chain <> bb1.chain and
		bb.length < bb1.length)
order by b_id, blocker, level, blockee

select 'CHAIN STATEMENTS'

select b.b_id, bb.blockee, inb.EventInfo  from btr_DBCCINB inb join btr_sysprocesses sp on inb.sp_id = sp.sp_id
		join btr_batch b on b.b_id between sp.b_id_beg and sp.b_id_end
		join #blockee_blocker bb on bb.b_id = b.b_id and bb.blockee = sp.spid
	where exists (select  bb_.blocker from #blockee_blocker bb_
				where not exists (select * from #blockee_blocker bb1 
						where bb_.length < bb1.length)
				and (bb.blocker = bb_.blocker or bb.blockee = bb_.blocker)
			)
order by b.b_id, level, blockee 

