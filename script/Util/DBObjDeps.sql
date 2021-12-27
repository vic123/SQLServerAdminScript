IF OBJECT_ID('GSODep') IS NOT NULL and (select count(*) from GSODep) = 0
  drop table GSODep
go

create table GSODep (
	path		varchar(200) NOT NULL,
	dpn_o_id	int NOT NULL,
	mst_o_id	int NOT NULL,
	isfrwd 		bit NOT NULL,
	isbkwd 		bit NOT NULL
)
alter table GSODep Add Primary Key (path )
go

set nocount on
declare @so_type varchar(10), @debug int
select @so_type = '[UVP]'
select @debug = 0
declare sod_cur cursor for 
	select distinct so_dpn.id as so_dpn_id, so_mst.id as so_mst_id, 
		convert(varchar(30), so_dpn.name) as so_dpn_name, 
		convert(varchar(30), so_mst.name) as so_mst_name
	from sysobjects so_dpn
	join sysdepends sdep on sdep.id = so_dpn.id and so_dpn.type like @so_type
	join sysobjects so_mst on sdep.depid = so_mst.id 
--				and so_mst.type in ('U', 'V', 'P')
				and so_mst.type like @so_type


open sod_cur
declare @so_dpn_id int, @so_mst_id int, @so_dpn_name varchar(30), @so_mst_name varchar(30)  
while (1=1) begin
	fetch next from sod_cur into @so_dpn_id, @so_mst_id, @so_dpn_name, @so_mst_name 
	if (@@fetch_status <> 0) break

	if (@debug & 1 <> 0) BEGIN
		select GSODep.path + @so_dpn_name + ':', @so_dpn_id, mst_o_id, 1, 0 
		from GSODep where GSODep.path like '%:' + @so_mst_name + ':'
	END

	insert into GSODep (path, dpn_o_id, mst_o_id, isfrwd, isbkwd) 	
	select GSODep.path + @so_dpn_name + ':', @so_dpn_id, mst_o_id, 1, 0 
	from GSODep where GSODep.path like '%:' + @so_mst_name + ':'
		and GSODep.isfrwd = 1

	insert into GSODep (path, dpn_o_id, mst_o_id, isfrwd, isbkwd) 	
	select GSODep.path +  @so_mst_name + ':', @so_dpn_id, mst_o_id, 0, 1 
	from GSODep 
		where GSODep.path like '%:' + @so_dpn_name + ':'
			and GSODep.isbkwd = 1

	if (@debug & 1 <> 0) 
		select ':' + @so_mst_name + GSODep.path, dpn_o_id, @so_mst_id, 1, 0 
		from GSODep where GSODep.path like ':' + @so_dpn_name + ':%'

	insert into GSODep (path, dpn_o_id, mst_o_id, isfrwd, isbkwd) 	
	select ':' + @so_mst_name + GSODep.path, dpn_o_id, @so_mst_id, 1, 0 
	from GSODep where GSODep.path like ':' + @so_dpn_name + ':%'
		and GSODep.isfrwd = 1

	insert into GSODep (path, dpn_o_id, mst_o_id, isfrwd, isbkwd) 	
	select ':' + @so_dpn_name + GSODep.path, dpn_o_id, @so_mst_id, 0, 1 
	from GSODep where GSODep.path like ':' + @so_mst_name + ':%'
			and GSODep.isbkwd = 1

	if (@debug & 1 <> 0) 
		select ':' + @so_mst_name + ':' + @so_dpn_name + ':', @so_dpn_id, @so_mst_id, 1, 0

	insert into GSODep (path, dpn_o_id, mst_o_id, isfrwd, isbkwd) 	
	values (':' + @so_mst_name + ':' + @so_dpn_name + ':', @so_dpn_id, @so_mst_id, 1, 0)

	insert into GSODep (path, dpn_o_id, mst_o_id, isfrwd, isbkwd) 	
	values (':' + @so_dpn_name  + ':' + @so_mst_name + ':', @so_dpn_id, @so_mst_id, 0, 1)

end
close sod_cur 
deallocate sod_cur 

/*
select count(*), id, name from GSODep join sysobjects so on GSODep.mst_o_id = id
group by id, name
order by count(*) desc, name
*/

select * from GSODep order by isfrwd, path
select * from GSODep 
	WHERE path NOT LIKE '%ADM_WRITE_SQL_ERR_LOG:_%'
	and isfrwd = 0 
	order by isfrwd, path

select * from GSODep 
	WHERE path LIKE ':ADM_WRITE_SQL_ERR_LOG:%'
	and isfrwd = 0
	order by isfrwd, path


select * from GSODep 
	WHERE path LIKE ':aspr_DrivesFreeSpaceControl:%'
		AND path NOT LIKE '%ADM_WRITE_SQL_ERR_LOG:_%'
	and isfrwd = 0 
	order by isfrwd, path


select * from GSODep 
	WHERE path LIKE ':aspr_DrivesFreeSpaceControl:%'
	and isfrwd = 0 
	order by isfrwd, path + '_'




/*
:aspr_DrivesFreeSpaceControl:aspr_DFSC_DelOldFiles:ADM_WRITE_SQL_ERR_LOG:
--master filter
select * from GSODep join sysobjects so on GSODep.mst_o_id = id
where name like 'SPPerm'
order by path 
--dependant filter
select * from GSODep join sysobjects so on GSODep.dpn_o_id = id
where name like 'sv_SMove'
order by path 
*/

--select max(len(path)) from GSODep
/*
select * from GSODep where mst_o_id = 661785615
order by path 
*/

