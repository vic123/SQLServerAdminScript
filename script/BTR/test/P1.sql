select @@spid
waitfor delay '00:00:04'
begin tran
update btr_test
set val = 'P1' where id = 1
waitfor delay  '00:00:08'
commit