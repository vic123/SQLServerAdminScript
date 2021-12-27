--create procedure usp_blocking_report (@spid int, @beg datetime = NULL, @end datetime  = NULL) as begin 
exec usp_blocking_report 61

exec usp_blocking_audit
select * from btr_log

select * from btr_batch

/*
 (VB-030712_0148) - changed for CVS test
*/

select * from btr_sysprocesses_tmp
select distinct spid  from btr_sysprocesses

select * from btr_Params

select * from master.dbo.sysprocesses where dbid = 6
select * from master.dbo.sysdatabases

exec usp_blocking_audit @Action = 'STOP'

