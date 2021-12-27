drop view btrv_LastRunParams
go
create view btrv_LastRunParams as 
select time, action, p.name, p.value, uname from btr_Params p join btr_PHistory ph on p.ph_id = ph.ph_id
where p.ph_id >= (select max (ph_id) from btr_Params where name = 'Running')
go

