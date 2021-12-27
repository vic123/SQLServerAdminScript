IF EXISTS (SELECT * FROM SYSOBJECTS WHERE NAME = 'btr_test' AND TYPE = 'U')
	drop table btr_test
create table btr_test(id int, val varchar(30))

delete btr_syslockinfo_tmp
delete btr_syslockinfo_tmp
--(MOD-030605)DPRCT b_id_enddelete btr_DBCCINB_tmp
delete btr_sysprocesses_tmp
delete btr_Params
delete btr_DBCCINB
delete btr_syslockinfo
delete btr_sysprocesses
delete btr_LOG
delete btr_sysjobhistory
delete btr_Batch

insert into btr_test(id, val) values (1, 'Initial')
insert into btr_test(id, val) values (2, 'Initial')
insert into btr_test(id, val) values (3, 'Initial')
--exec usp_blocking_audit @Action = 'START', @Delay = '00:00:01', @ActionKill = 0, @KillCount = 0, @KillMSecs = 0, @MaxCPU = 1000
exec usp_blocking_audit @Action = 'START', @Delay = '00:00:01', @ActionKill = 0, @KillCount = 0, @KillMSecs = 0, @MaxCPU = 1000, @DoLockTrace = 1

--, @KillAction = 0, @KillCount = 0, @KillMSecs = 0