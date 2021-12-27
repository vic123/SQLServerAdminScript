/*
vic - this is adopted for 6.5 version. All comments were left untouched.
Changes are marked with --vic
By: keithh 
With a dynamic sql script under 4000 chars use sp_executesql
With under 8000 chars write it to a variable.

For anything longer you can use this script.  Use UpdateText and WriteText to write your dynamic sql to a text/ntext field in a table somewhere and then pass its location to this script.


*/

/*	This can execute dynamically generated SQL statements
	up to approx 156000 chars in length.

	Since you can't pass this as a variable the proc takes
	the table and fieldname of a text value to execute.

	A where statement can be included and should fully 
	declare the table name.  Try to keep this statement as
	simple as possible.

	This can also handle fields in #temp tables		*/
drop proc executelargesql --vic
go
--vic create proc executelargesql(@tablename sysname, @fieldname sysname, @where nvarchar(3000) = null) as
create proc executelargesql(@tablename sysname, @fieldname sysname, @where varchar(255) = null) as
begin
--vic	declare @len int, @isql nvarchar(4000), @i int, @lsql nvarchar(4000), @type sysname
	declare @len int, @isql varchar(255), @i int, @lsql varchar(255) --vic, @type sysname
	create table #i (l int, h text) --#table created before sp_executesql will be visible inside it

--vic	if left(@tablename, 1) = '#'	--we have a # table as source, look in temp db
--vic	if substring(@tablename, 1, 1) = '#'	--we have a # table as source, look in temp db
--vic		select @type = t.name from tempdb.dbo.sysobjects o inner join tempdb.dbo.syscolumns c on o.id = c.id inner join tempdb.dbo.systypes t on c.xtype = t.xtype where left(o.name, len(@tablename)) = @tablename and c.name = @fieldname
--vic		select @type = t.name from tempdb.dbo.sysobjects o inner join tempdb.dbo.syscolumns c on o.id = c.id inner join tempdb.dbo.systypes t on c.xtype = t.xtype where substring(o.name, 1, len(@tablename)) = @tablename and c.name = @fieldname
--vic	else				--we have a user table as source
--vic		select @type = t.name from dbo.sysobjects o inner join dbo.syscolumns c on o.id = c.id inner join dbo.systypes t on c.xtype = t.xtype where o.name = @tablename and c.name = @fieldname

	-- we need to get the length of the field we are dealing with
--vic	if @type in ('ntext', 'nvarchar', 'nchar') --we have to half the datalength for unicode data types
--vic		set @isql = 'insert #i (l,h) select datalength('+@tablename+'.'+@fieldname+')/2,['+@tablename+'].['+@fieldname+'] from dbo.['+@tablename+']'+isnull(' where '+@where,'')
--vic	else
--vic		set @isql = 'insert #i (l,h) select datalength('+@tablename+'.'+@fieldname+'),['+@tablename+'].['+@fieldname+'] from dbo.['+@tablename+']'+isnull(' where '+@where,'')
		select @isql = 'insert #i (l,h) select datalength('+@tablename+'.'+@fieldname+'),'+@tablename+'.'+@fieldname+' from dbo.'+@tablename+' '+isnull(' where '+@where,'')

--vic	exec sp_executesql @isql --this statement should only return 1 row, more means a crap @where clause, less means nothing to exec
	exec (@isql) --this statement should only return 1 row, more means a crap @where clause, less means nothing to exec
	if @@error <> 0 or @@rowcount <> 1 goto doh
	
	select @isql = '', @i = 0, @lsql = null, @len = v.l from #i v
	
--	declare @stmnt varchar(255)
	select 	@isql = 'declare @ptrval  varbinary(16), @t0 varchar(255), @t255 varchar(255), @t510 varchar(255), @t765 varchar(255)' 
	while @i <= @len begin --this can loop up to 39 times before it becomes too big for sp_executesql to handle
--		select @stmnt = READTEXT 
		select @isql = @isql + char(10) +
--vic			'declare @t' + cast(@i as varchar) + ' nvarchar(4000)' + char(10) + 
			'declare @t' + convert(varchar(10), @i) + ' varchar(255)' + 'char(10) + 
--vic			'select @t' + cast(@i as varchar) + '=substring(h,' + cast(@i as varchar) + ',4000) from #i',
			'select @t' + convert(varchar(10), @i) + '=substring(h,' + convert(varchar(10), @i) + ',255) from #i',
--vic			@lsql = isnull(@lsql + '+','') + '@t' + cast(@i as varchar), 
			@lsql = isnull(@lsql + '+','') + '@t' + convert(varchar(10), @i), 
--vic			@i = @i + 4000
			@i = @i + 255
	end
	
	
	select @isql = @isql + char(10) + 'exec (' + substring (@lsql, 2, len(@lsql))  + ')'
	
--vic	exec sp_executesql @isql
--	exec (@isql)
	select @isql
	if @@error <> 0 goto doh

	goto done
	doh:
		print 'An error has occured '
		select len(@isql) as isqllen, @isql as internalexecutesql, @lsql as statementlist, @i as counter --vic, @type as execfield_datatype
		select * from #i
	done:
		drop table #i
end

