/*
By: Serge Shakhov 
This Stored Procedure will display object level permissions
for stated User or Role.
Procedure output is ready to execute batch.
Usage:
  Exec ScriptPermissions 'public' 

*/

Create Procedure ScriptPermissions @user varchar(30)=null
AS
create table #t 
(a1 varchar(50)
,a2 varchar(50)
,a3 varchar(50)
,a4 varchar(50)
,a5 varchar(50)
,a6 varchar(50)
,a7 varchar(50))
insert into #t exec sp_helprotect @username = @user
select a5+' '+a6+' on ['+a1+'].['+a2+']'+
CASE
 WHEN (PATINDEX('%All%', a7)=0) and (a7 <> '.') 
  THEN ' ('+a7+')'
 ELSE ''
END+' to ['+a3+']' from #t
drop table #t
GO



