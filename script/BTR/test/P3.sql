select @@spid
waitfor delay '00:00:04'
begin tran
waitfor delay '00:00:04'
update btr_test set val = 'P3' where id  = 2
commit

waitfor delay '00:00:012' --wait until BTR stopped

--exec usp_blocking_report @@spid
select * from btr_batch
select * from btr_log
exec usp_blocking_report @in_brief = 1