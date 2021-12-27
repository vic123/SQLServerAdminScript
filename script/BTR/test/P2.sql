select @@spid
waitfor delay '00:00:04'
begin tran
update btr_test set val = 'P2' where id  = 2
waitfor delay '00:00:04'
update btr_test set val = 'P2' where id  = 1
commit
