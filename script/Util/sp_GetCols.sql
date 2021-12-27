SET NOCOUNT ON
GO
/*
PRINT 'Using Master database'
USE master
*/
GO
IF (SELECT OBJECT_ID('sp_GetCols','P')) IS NOT NULL --means, the procedure already exists
		DROP PROC sp_GetCols 
GO

--Turn system object marking on
--EXEC master.dbo.sp_MS_upd_sysobj_category 1
GO

CREATE PROC sp_GetCols @TableName varchar(200), @UseSys bit = 1, @UseSQB bit = 1
AS 

SET NOCOUNT ON	
DECLARE @Separator varchar(2),
	 @Prefix char(1),
	@BOpen varchar(1), @BClose varchar(1) 
	
SET @Separator = ', '
SET @Prefix ='@'
SET @BClose = ''
SET @BOpen = ''

if (@UseSQB = 1) begin 
	SET @BClose = ']'
	SET @BOpen = '['
end



if (@UseSys = 1) begin
	declare @stmnt varchar(8000)

	select @stmnt = ''
	SELECT @stmnt = @stmnt + 
		CAST( @BOpen + sc.NAME + @BClose + @Separator AS varchar(200))
	FROM syscolumns sc join sysobjects so on sc.id = so.id
	WHERE so.name = @TableName
	order by colorder
	SELECT @stmnt as ColumnName

	select @stmnt = ''
	SELECT @stmnt = @stmnt + 
		CAST( sc.NAME + @Separator AS varchar(200))
	FROM syscolumns sc join sysobjects so on sc.id = so.id
	WHERE so.name = @TableName
	order by colorder
	SELECT @stmnt as ColumnName

	select @stmnt = ''
	SELECT @stmnt = @stmnt + 
		CAST( @Prefix + sc.NAME +' '+ st.name
		 + 	CAST 	(CASE	
				WHEN sc.scale is null THEN '('+ CONVERT(varchar(7),sc.length)+')' + @Separator  COLLATE database_default
				ELSE @Separator
				END AS varchar(7))
			AS varchar(200)) 
		
	FROM syscolumns sc join sysobjects so on sc.id = so.id
	join systypes st on sc.xtype = st.xtype
	WHERE st.xtype = st.xusertype
	and so.name = @TableName
	order by colorder
	SELECT @stmnt as Declaration

	select @stmnt = ''
	SELECT @stmnt = @stmnt + 
		CAST(@Prefix + sc.NAME + @Separator as varchar(200) )
	FROM syscolumns sc join sysobjects so on sc.id = so.id
	WHERE so.name = @TableName
	order by colorder
	SELECT @stmnt as Parameter

	select @stmnt = ''
	SELECT @stmnt = @stmnt + 
		CAST(@BOpen + sc.NAME + @BClose + ' = ' + @Prefix + sc.NAME + @Separator as varchar(400) ) 
	FROM syscolumns sc join sysobjects so on sc.id = so.id
	WHERE so.name = @TableName
	order by colorder
	SELECT @stmnt as Assignment

	select @stmnt = ''
	SELECT @stmnt = @stmnt + 
		CAST(@BOpen + sc.NAME + @BClose + ' = ' + sc.NAME + @Separator as varchar(400) ) 
	FROM syscolumns sc join sysobjects so on sc.id = so.id
	WHERE so.name = @TableName
	order by colorder
	SELECT @stmnt as Assignment


end else begin
	SELECT CAST( COLUMN_NAME + @Separator AS varchar(200))as ColumnName
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = @TableName

	SELECT CAST( @Prefix + COLUMN_NAME +' '+ DATA_TYPE
	 + 	CAST 	(CASE	
			WHEN CHARACTER_MAXIMUM_LENGTH <> 0 THEN '('+ CONVERT(varchar(7),CHARACTER_MAXIMUM_LENGTH)+'),'  COLLATE database_default
			ELSE ',' 
			END AS varchar(7))
		AS varchar(200)) 
	AS Declaration
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = @TableName 

	SELECT CAST(@Prefix + COLUMN_NAME + @Separator as varchar(200) )AS Parameter
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = @TableName

	SELECT CAST(COLUMN_NAME + ' = ' + @Prefix + COLUMN_NAME + ',' as varchar(400) ) AS Assignment
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = @TableName
end
GO

--Turn system object marking off
--EXEC master.dbo.sp_MS_upd_sysobj_category 2
GO

--PRINT 'Granting EXECUTE permission on sp_generate_inserts to all users'
--GRANT EXEC ON sp_GetCols TO public

SET NOCOUNT OFF
GO

