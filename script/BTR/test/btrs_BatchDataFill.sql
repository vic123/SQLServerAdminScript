--select * from btr_Batch
--exec up_GetCols btr_Batch

set nocount on
--begin tran
declare @start_dt datetime
select @start_dt = '2003-06-13 06:19:40.740'
declare @min_batch_s int, @max_batch_s int
select @min_batch_s = 1, @max_batch_s = 60
declare @min_delay_s int, @max_delay_s int
--select 15 *60
select @min_delay_s = 5, @max_delay_s = 900

declare @i int, @bcnt int, @rnd float
select @i = 0, @bcnt = 10000
declare @time_beg datetime, @time_end datetime
select @time_end = @start_dt

select @rnd = RAND(0)
while (@i < @bcnt) begin
--	select @rnd = RAND(@i*2)
	select @rnd = RAND()
--	select @rnd 
	select @time_beg = dateadd(ss, @min_delay_s + ROUND(@rnd * (@max_delay_s - @min_delay_s), 0), @time_end)
--	select @rnd = RAND(@i*2+1)
	select @rnd = RAND()
--	select @rnd 
	select @time_end = dateadd(ss, @min_batch_s + ROUND(@rnd * (@max_batch_s - @min_batch_s), 0), @time_beg)
	insert into btr_Batch(time_beg, time_end) values ( @time_beg, @time_end)
	select @i = @i + 1
end
--select * from btr_Batch
--rollback







