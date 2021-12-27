exec sp_spaceused

declare syso_cur cursor for select name from sysobjects where name like 'btr_%' and type = 'U'
open syso_cur
declare @btrt_name varchar (100)
while (1= 1) begin
	fetch next from syso_cur into @btrt_name
	if (@@fetch_status <> 0) break
	exec ('sp_spaceused ' + @btrt_name + ', true')
end
close syso_cur
deallocate syso_cur


