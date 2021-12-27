if exists (select * from sysobjects where name = 'btrp_RptGAP' and type = 'P')
drop procedure btrp_RptGAP
go
create procedure btrp_RptGAP (@MinGapSecs int = NULL, @DelayGap bit = 1, @BatchGap bit = 1) as begin
	set nocount on
	declare @Result	int	
	select @Result = 0
	if @MinGapSecs is NULL begin
		PRINT 'Usage: btrp_RptGAP 	@MinGapSecs = nn'
		PRINT '				[, @DelayGap  = 0|1(1)] '
		PRINT '				[, @BatchGap  = 0|1(1)] '
		PRINT '@MinGapSecs	- minimal gaps in seconds that should be reported'
		PRINT '@DelayGap	- report on strict non-activity gaps, including only delay between batches'
		PRINT '@BatchGap	- report on nonstrict gaps, including execution and delay batch times'
		select @Result = @Result | 1
		goto err
	end
	if exists (select * from btr_Batch where time_end < time_beg) begin
		select 'Inconsistences detected in btr_Batch table (time_end < time_beg):'
		select * from btr_Batch where time_end < time_beg
	end
	if exists (select * from btr_Batch join btr_Batch btr_b_follow on btr_Batch.time_end >  btr_b_follow.time_beg 
								and btr_Batch.time_beg <  btr_b_follow.time_beg) begin
		select 'Inconsistences detected in btr_Batch table (btr_Batch.time_end >  btr_b_follow.time_beg	and btr_Batch.time_beg <  btr_b_follow.time_beg):'
		select * from btr_Batch join btr_Batch btr_b_follow on btr_Batch.time_end >  btr_b_follow.time_beg 
								and btr_Batch.time_beg <  btr_b_follow.time_beg
	end
	if exists (select * from btr_Batch join btr_Batch btr_b_follow on btr_Batch.time_beg <  btr_b_follow.time_beg 
								and btr_Batch.time_end >  btr_b_follow.time_beg) begin
		select 'Inconsistences detected in btr_Batch table (btr_Batch.time_beg <  btr_b_follow.time_beg	and btr_Batch.time_beg >  btr_b_follow.time_beg):'
		select * from btr_Batch join btr_Batch btr_b_follow on btr_Batch.time_end <  btr_b_follow.time_beg 
								and btr_Batch.time_beg >  btr_b_follow.time_beg
	end
	select datediff(ss, isnull(btr_beg.time_end, btr_beg.time_beg), btr_end.time_beg) strict_gap, datediff(ss, btr_beg.time_beg, btr_end.time_beg) nonstrict_gap, 
	btr_beg.b_id as gap_beg_b_id, btr_beg.time_beg as gap_beg_time_beg, btr_beg.time_end as gap_beg_time_end, 
	btr_end.b_id as gap_end_b_id, btr_end.time_beg as gap_end_time_beg, btr_end.time_end as gap_end_time_end 
	into #btr_Batch_GAP
	from btr_Batch btr_beg, btr_Batch btr_end
	where btr_end.b_id = (select min(b_id) from btr_Batch min_id 
							where min_id.time_beg = (select min(time_beg) from  btr_Batch min_time 
									where min_time.time_beg >= btr_beg.time_beg 
									and min_time.b_id <> btr_beg.b_id)
							and min_id.b_id <> btr_beg.b_id)
	and (	(datediff(ss, btr_beg.time_beg, btr_end.time_beg) >= @MinGapSecs)
		or 
		(datediff(ss, btr_beg.time_end, btr_end.time_beg) >= @MinGapSecs)
	)


/*(MOB-030614)	from btr_Batch btr_beg join 
		btr_Batch btr_end on (datediff(ss, btr_beg.time_beg, btr_end.time_beg) >= @MinGapSecs
				or datediff(ss, btr_beg.time_end, btr_end.time_beg) >= @MinGapSecs)
	where not exists (select * from btr_Batch where btr_Batch.time_beg < btr_end.time_beg
								and btr_Batch.time_beg >= isnull(btr_beg.time_end, btr_beg.time_beg)
								and btr_Batch.b_id <> btr_end.b_id)
*/

	if (isnull(@DelayGap, 1) = 1) begin
		select 'Strict gaps (between batch time_end and next batch time_beg):'
		select strict_gap, gap_beg_time_end, gap_end_time_beg from #btr_Batch_GAP where strict_gap >= @MinGapSecs
	end
	if (isnull(@BatchGap, 1) = 1) begin
		select 'Nonstrict GAPs (between batch time_beg and next batch time_beg):'
		select nonstrict_gap, gap_beg_time_beg, gap_end_time_beg from #btr_Batch_GAP where nonstrict_gap >= @MinGapSecs
	end
	return 0
--	select * from #btr_Batch_GAP
err:
	return @Result
end
go

/*
src\test\datafill\btrs_BatchDataFill.sql is a script for btr_Batch filling
Samples:
exec btrp_RptGAP 600 
Returns periods greater that 10 minutes which was possible tracing data to get loosed 
exec btrp_RptGAP 900, 1, 0
Returns 15 minutes or longer gaps that occured between end of a batch and next start.
Notes (todo):
To distinguish batches when CPU protection was active and therefore consider them as gap compositors. 
*/

