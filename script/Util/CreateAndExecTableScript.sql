IF OBJECT_ID('CreateAndExecTableScript ') IS NOT NULL  
  DROP PROCEDURE CreateAndExecTableScript 
GO

CREATE PROCEDURE CreateAndExecTableScript 
(@DBName sysname = NULL,
@TableName varchar(255) = '', 
@TableNameExt varchar(10) = '', 
@DisplayScript bit = 1, 
@Exec bit = 0, 
@NoPK bit = 0, 
@PKOnly bit = 0, 
@NoIndexes bit = 0, 
@NoTable bit = 0,
@SQLDrop varchar(8000) = NULL OUTPUT, 
@SQLCreate varchar(8000) = NULL OUTPUT, 
@SQLPK varchar(8000) = NULL OUTPUT, 
@SQLDF varchar(8000) = NULL OUTPUT, 
@SQLIndex varchar(8000) = NULL OUTPUT 


/*
By: rmarda 
This SP will only work on SQL Server 2000 and can be placed in your master database. 
sp_CreateAndExecTableScript is designed to script one table and create an identical table. 
I designed it to use with DTS packages so that I can create an identical table with a different name, 
pump data into the table and then rename the new table to the name of the original table. 
Here is a sample call for the stored procedure to script everything related to a table: 
exec sp_CreateAndExecTableScript @Exec = 1, @DisplayScript = 1, @TableName = 'authors', 
				@TableNameExt = '_New' 
This will create a duplicate table in the pubs database for the table authors. 
If you set @NoIndexes = 1 and @NoPK = 1 then you will only get the table and default values. 
If you set @PKOnly = 1 then you will only get the script for the primary key. 
If you set @NoTable = 1 then you will only get the script for the primary key and/or the indexes. 
If you want to see the script without executing it then make sure you set @Exec = 0 and @DisplayScript = 1. 
I do not guarantee it will script all tables correctly, however my testing shows it will script most tables 
and indexes correctly. If you find something about a table or index it doesn't script properly please let me know 
and I will see about fixing it. 
*/


/*
Created by: Robert W. Marda
When completed: 11 Oct 2002

Purpose:  Build script to create a table with default values 
and/or its primary key and/or its indexes.

Modified by vic123:
added output parameters
added DBName and ability to script table from another db.
added minimal error handling
*/

)AS

SET NOCOUNT ON

--Begin invalid entries for parameters section

--Test for empty entry
/*
IF @TableName = ''
BEGIN
	PRINT '@TableName is a required parameter.'

	RETURN 1
END
*/
--Test for source table
/*
IF NOT EXISTS (select * from sysobjects where id = object_id(N'[dbo].[' + @TableName + ']') 
		and OBJECTPROPERTY(id, N'IsUserTable') = 1)
BEGIN
	PRINT 'Table ' + @TableName + ' not found.'

	RETURN 2
END
*/
--End invalid entries for parameters section

DECLARE @Query varchar (8000)
DECLARE @sql nvarchar(4000), @err int


SET @Query = ''
SET @SQLDF = ''
SET @SQLCreate = ''
SET @SQLPK = ''
SET @SQLIndex = ''

--Begin building datetime value to be used to ensure primary key and index names are unique
DECLARE @DateTime varchar(20)
DECLARE @rawDateTime varchar(20)

SET @rawdatetime = CURRENT_TIMESTAMP
SET @DateTime = SUBSTRING(@rawDateTime, 5, 2) + LEFT(@rawDateTime, 3) + SUBSTRING(@rawDateTime, 8, 4)

IF SUBSTRING(@rawDateTime, 13, 1) = ' '
	SET @DateTime = @DateTime + SUBSTRING(@rawDateTime, 14, 1)
ELSE
	SET @DateTime = @DateTime + SUBSTRING(@rawDateTime, 13, 2)

SET @DateTime = LTRIM(@DateTime) + '_' + SUBSTRING(@rawDateTime, 16, 4)
--End building datetime value

--Begin creating temp tables

--temp table #TableScript is used to gather data needed to generate script that will create the table
IF @NoTable = 0 AND @PKOnly = 0
	CREATE TABLE #TableScript (
		ColumnName varchar (30),
		DataType varchar(40),
		Length varchar(4),
		[Precision] varchar(4),
		Scale varchar(4),
		IsNullable varchar(1),
		TableName varchar(30),
		ConstraintName varchar(255),
		DefaultValue varchar (255),
		GroupName varchar(35),
		collation sysname NULL,
		IdentityColumn bit NULL
	)

--temp table #IndexScript is used to gather data needed to generate script that will create indexes for table
CREATE TABLE #IndexScript (
	IndexName varchar (255),
	IndId int,
	ColumnName varchar (255),
	IndKey int,
	UniqueIndex int
)

--End creating temp tables

SELECT @DBName = isNull(@DBName, db_name())

--Begin filling temp table #TableScript
IF @NoTable = 0 AND @PKOnly = 0
BEGIN

	SELECT @sql = 'USE ' + @DBName + CHAR(10) 
		+ 'INSERT INTO #TableScript (ColumnName, DataType, Length, [Precision], Scale, IsNullable, TableName, ' + CHAR(10) 
		+ '		  ConstraintName, DefaultValue, GroupName, collation, IdentityColumn)' + CHAR(10) 
		+ 'SELECT  LEFT(c.name,30) AS ColumnName, ' + CHAR(10) 
		+ 'LEFT(t.name,30) AS DataType, ' + CHAR(10) 
		+ 'CASE t.length' + CHAR(10) 
		+ '	WHEN 8000 THEN c.prec  ' + CHAR(10)  --This criteria used because Enterprise Manager delivers the length in parenthesis for these datatypes when using its scripting capabilities.'
		+ '	ELSE NULL' + CHAR(10) 
		+ 'END AS Length, ' + CHAR(10) 
		+ 'CASE t.name' + CHAR(10) 
		+ '	WHEN ''numeric'' THEN c.prec' + CHAR(10) 
		+ '	WHEN ''decimal'' THEN c.prec' + CHAR(10) 
		+ '	ELSE NULL' + CHAR(10) 
		+ 'END AS [Precision],' + CHAR(10) 
		+ 'CASE t.name' + CHAR(10) 
			+ 'WHEN ''numeric'' THEN c.scale' + CHAR(10) 
			+ 'WHEN ''decimal'' THEN c.scale' + CHAR(10) 
			+ 'ELSE NULL' + CHAR(10) 
		+ 'END AS Scale,' + CHAR(10) 
		+ 'c.isnullable,' + CHAR(10) 
		+ 'LEFT(o.name,30) AS TableName, ' + CHAR(10) 
		+ 'd.name AS ConstraintName, ' + CHAR(10) 
		+ 'cm.text AS DefaultValue, ' + CHAR(10) 
		+ 'g1a.groupname,' + CHAR(10) 
		+ 'c.collation,' + CHAR(10) 
		+ 'CASE ' + CHAR(10) 
		+ '	WHEN c.autoval IS NULL THEN 0' + CHAR(10) 
		+ '	ELSE 1' + CHAR(10) 
		+ 'END AS IdentityColumn' + CHAR(10) 
	+ 'FROM syscolumns c ' + CHAR(10) 
	+ 'INNER JOIN sysobjects o ON c.id = o.id' + CHAR(10) 
	+ 'LEFT JOIN systypes t ON t.xusertype = c.xusertype' + CHAR(10)  --the first three joins get column names, data types, and column nullability.
	+ 'LEFT JOIN sysobjects d ON c.cdefault = d.id' + CHAR(10)  --this left join gets column default constraint names.
	+ 'LEFT JOIN syscomments cm ON cm.id = d.id' + CHAR(10)  --this left join gets default values for default constraints.
	+ 'LEFT JOIN sysindexes g1 ON g1.id = o.id' + CHAR(10)  --the left join for sysfilegroups and sysindexes with aliases g1 and g1a
	+ 'LEFT JOIN sysfilegroups g1a ON g1.groupid = g1a.groupid' + CHAR(10)  --are for determining which file group the table is in.
	+ 'WHERE o.name = ''' + @TableName +'''' + CHAR(10) 
	+ 'AND g1.id = o.id AND g1.indid in (0, 1)'  --these two conditions are to isolate the file group of the table.

	EXEC @err = sp_executesql @sql
	IF @err <> 0 GOTO Err
END
--End filling temp table #TableScript

--SELECT * FROM #TableScript
--Begin building create table and default value constraints scripts.
IF @NoTable = 0 AND @PKOnly = 0
BEGIN
	SET @SQLDrop = 'if exists (select * from sysobjects where id = object_id(N' + '''[dbo].[' 
		+ @TableName + @TableNameExt + ']''' + ') and OBJECTPROPERTY(id, N' + '''IsUserTable''' + ') = 1)'
		+ CHAR(10) + 'drop table [dbo].[' + @TableName + @TableNameExt + ']'
		+ CHAR(10) 
	SET @Query = @SQLDrop + 'GO' + CHAR(10) 
	SET @SQLCreate = CHAR(10) + 'CREATE TABLE [dbo].[' + @TableName + @TableNameExt + '] ('

	DECLARE @DataType varchar(40),
		@Length varchar(4),
		@Precision varchar(4),
		@Scale varchar(4),
		@Isnullable varchar(1),
		@DefaultValue varchar(255),
		@GroupName varchar(35),
		@ColumnName varchar(255),
		@ConstraintName varchar(255),
		@collation sysname,
		@TEXTIMAGE_ON bit,
		@IdentityColumn bit

	SET @TEXTIMAGE_ON = 0

	DECLARE ColumnName Cursor For
	SELECT ColumnName
	FROM #TableScript

	OPEN ColumnName

	FETCH NEXT FROM ColumnName INTO @ColumnName

	WHILE (@@fetch_status = 0)
	BEGIN
		SELECT  @DataType = DataType, 
			@Length = Length,
			@Precision = [Precision],
			@Scale = Scale, 
			@Isnullable = isnullable,
			@DefaultValue = DefaultValue,
			@ConstraintName = ConstraintName,
			@collation = collation,
			@IdentityColumn = IdentityColumn
		FROM #TableScript
		WHERE ColumnName = @ColumnName

		IF @DefaultValue IS NOT NULL
		BEGIN

			IF @SQLDF = ''
				SET @SQLDF = @SQLDF 
					+ CHAR(10) + CHAR(10) + 'ALTER TABLE [dbo].[' + @TableName + @TableNameExt + '] WITH NOCHECK ADD'
	
			SET @SQLDF = @SQLDF 
				+ CHAR(10) + CHAR(9) + 'CONSTRAINT [DF_' + @TableName + @TableNameExt + '_' 
				+ @ColumnName + '_' + @DateTime + '] DEFAULT ' + @DefaultValue 
				+ ' FOR [' + @ColumnName + '],'

		END

		IF @DataType = 'text' OR @DataType = 'ntext'
			SET @TEXTIMAGE_ON = 1

		SET @SQLCreate = @SQLCreate 
			+ CHAR(10) + CHAR(9) + '[' + @ColumnName + '] [' + @DataType + ']'

		IF @DataType = 'varchar' OR @DataType = 'nvarchar' OR @DataType = 'char' OR @DataType = 'nchar'
		   OR @DataType = 'varbinary' OR @DataType = 'binary'
			SET @SQLCreate = @SQLCreate 
				+ ' (' + @Length + ')'

		IF @DataType = 'numeric' OR @DataType = 'decimal'
			SET @SQLCreate = @SQLCreate 
				+ ' (' + @Precision + ', ' + @Scale + ')'

		IF @IdentityColumn = 1
			SET @SQLCreate = @SQLCreate
				+ ' IDENTITY (' + LTRIM(STR(isNull(IDENT_SEED(@TableName), 1))) + ', ' + LTRIM(STR(isNull(IDENT_INCR(@TableName), 1))) + ')'

	
		IF @collation IS NOT NULL AND @DataType <> 'sysname' AND @DataType <> 'ProperName'
			SET @SQLCreate = @SQLCreate
				+ ' COLLATE ' + @collation

		IF @Isnullable = '1'
			SET @SQLCreate = @SQLCreate + ' NULL'
		ELSE
			SET @SQLCreate = @SQLCreate + ' NOT NULL'
	
		FETCH NEXT FROM ColumnName INTO @ColumnName
	 
		IF @@fetch_status = 0
			SET @SQLCreate = @SQLCreate + ', '
	END

	CLOSE ColumnName
	DEALLOCATE ColumnName

	SET @SQLCreate = @SQLCreate 
		+ CHAR(10) + ')'

	--Assign file group name
	SELECT DISTINCT @GroupName = GroupName
	FROM #TableScript

	IF @GroupName IS NOT NULL
		SET @SQLCreate = @SQLCreate 
			+ ' ON [' + @GroupName + ']'

	IF @TEXTIMAGE_ON = 1
		SET @SQLCreate = @SQLCreate 
			+ ' TEXTIMAGE_ON [' + @GroupName + ']'

	IF RIGHT(@SQLDF,1) = ','
		SET @SQLDF = LEFT(@SQLDF, LEN(@SQLDF) - 1)

	SET @SQLCreate = @SQLCreate + CHAR(10) 

END
SET @Query = @Query + @SQLCreate + 'GO' 
--End building create table and default value constraints scripts.
--Begin filling temp table #IndexScript.
SELECT @sql = 'USE ' + @DBName + CHAR(10) 
		+ 'INSERT INTO #IndexScript (IndexName, IndId, ColumnName, IndKey, UniqueIndex)' + CHAR(10) 
		+ 'SELECT 	i.name, ' + CHAR(10) 
		+ '	i.indid,' + CHAR(10) 
		+ '	c.name, ' + CHAR(10) 
		+ '	k.keyno,' + CHAR(10) 
		+ '	(i.status & 2)' + CHAR(10)   --Learned this will identify a unique index from sp_helpindex
		+ 'FROM sysindexes i ' + CHAR(10) 
		+ 'INNER JOIN sysobjects o ON i.id = o.id' + CHAR(10) 
		+ 'INNER JOIN sysindexkeys k ON i.id = k.id AND i.indid = k.indid' + CHAR(10) 
		+ 'INNER JOIN syscolumns c ON c.id = k.id AND k.colid = c.colid' + CHAR(10) 
		+ 'WHERE o.name = ''' + @TableName + '''' + CHAR(10) 
		+ 'AND i.indid > 0 and i.indid < 255' + CHAR(10)  --eliminates non indexes
		+ 'AND LEFT(i.name,7) <> ''_WA_Sys''' + CHAR(10)   --eliminates statistic indexes
EXEC @err = sp_executesql @sql
IF @err <> 0 GOTO Err

--End filling temp table #IndexScript.

DECLARE @PK varchar(2),
	@IndID int,
	@IndexName varchar(255),
	@IndKey int

SET @PK = ''
SET @IndKey = 1

SELECT DISTINCT @IndexName = IndexName, 
		@IndID = indid
FROM #IndexScript
WHERE LEFT (IndexName, 2) = 'PK'

--Begin creating primary key script.
SET @SQLPK = ''
IF @PKOnly = 1 OR (@NoTable = 1 AND @NoPK = 0)
BEGIN
	SET @SQLPK = '--Add Primary Key' + CHAR(10)
	SET @PK = 'PK'
END
IF @NoPK = 0
BEGIN
	IF @IndexName IS NOT NULL
	BEGIN

		SET @SQLPK = @SQLPK 
			+ CHAR(10) + CHAR(10) + 'ALTER TABLE [dbo].[' + @TableName + @TableNameExt + '] WITH NOCHECK ADD'
			+ CHAR(10) + 'CONSTRAINT [PK_' + @TableName + @TableNameExt + @PK + '_' + @DateTime + '] PRIMARY KEY  '

		IF @IndID = 1
			SET @SQLPK = @SQLPK
				+ 'CLUSTERED'
		ELSE
			SET @SQLPK = @SQLPK
				+ 'NONCLUSTERED'


		SET @SQLPK = @SQLPK
			+ CHAR(10) + '('

		DECLARE @OldColumnName varchar(255)
		
		SET @OldColumnName = 'none_yet'
		
		WHILE @IndKey <= 16
		BEGIN
			SELECT @ColumnName = ColumnName
			FROM #IndexScript
			WHERE IndexName = @IndexName AND IndID = @IndID AND IndKey = @IndKey
		
			IF @ColumnName IS NOT NULL AND @ColumnName <> @OldColumnName
			BEGIN
				SET @SQLPK = @SQLPK
					+ CHAR(10) + '[' + @ColumnName + '],'
			END
		
			SET @OldColumnName = @ColumnName
			SET @IndKey = @IndKey + 1 
		END

		IF RIGHT(@SQLPK,1) = ','
			SET @SQLPK = LEFT(@SQLPK, LEN(@SQLPK) - 1)

		SET @SQLPK = @SQLPK
			+ CHAR(10) + ')'

		--Add file group name
		IF @GroupName is not null
			SET @SQLPK = @SQLPK
				+ ' ON [' + @GroupName + ']'

		SET @SQLPK = @SQLPK + CHAR(10) 
	END
	SET @Query = @Query + @SQLPK + 'GO'
END
--End creating primary key script.
--Add default value constraint script to main script.
IF @NoTable = 0 AND @PKOnly = 0
	SET @Query = @Query 
		+ @SQLDF
		+ CHAR(10) + 'GO'

--Begin building index script.
IF @NoIndexes = 0 AND @PKOnly = 0
BEGIN
	SET @SQLIndex = ''
	IF @NoPK = 0
		SET @SQLIndex = @SQLIndex 
			+ CHAR(10)

	IF @NoTable = 1
		SET @SQLIndex = @SQLIndex 
			+ '--Add Indexes' + CHAR(10)
	ELSE
		SET @SQLIndex = @SQLIndex
			+ CHAR(10)

	DECLARE @IndexNameOrig varchar(255), 
		@UniqueIndex int

	DECLARE IndexName Cursor For
	SELECT DISTINCT IndexName, 
			indid,
			UniqueIndex
	FROM #IndexScript
	WHERE LEFT (IndexName, 2) <> 'PK' AND LEFT(IndexName, 4) <> 'hind'

	OPEN IndexName
	
	FETCH NEXT FROM IndexName INTO @IndexName, @IndID, @UniqueIndex

	WHILE @@fetch_status = 0
	BEGIN
		SET @IndexNameOrig = @IndexName

		IF RIGHT(@IndexName,2) = 'PM' OR RIGHT(@IndexName,2) = 'AM'
			SET @IndexName = LEFT(@IndexName, LEN(@IndexName) - 5)

		IF LEFT(RIGHT(@IndexName,10),1) = '_'
			SET @IndexName = LEFT(@IndexName, LEN(@IndexName) - 10)
		ELSE
			IF LEFT(RIGHT(@IndexName,11),1) = '_'
				SET @IndexName = LEFT(@IndexName, LEN(@IndexName) - 11)
			ELSE
				IF LEFT(RIGHT(@IndexName,12),1) = '_'
					SET @IndexName = LEFT(@IndexName, LEN(@IndexName) - 12)

		SET @SQLIndex = @SQLIndex
			+ CHAR(10) + 'CREATE '

		IF @IndID = 1
			SET @SQLIndex = @SQLIndex
				+ 'CLUSTERED '

		IF @UniqueIndex <> 0
			SET @SQLIndex = @SQLIndex
				+ 'UNIQUE '

		SET @SQLIndex = @SQLIndex
			+ 'INDEX [' + @IndexName + '_' + @DateTime + '] ON [dbo].[' + @TableName + @TableNameExt + ']('

		SET @IndKey = 1
		SET @OldColumnName = 'none_yet'

		WHILE @IndKey <= 16
		BEGIN
			SELECT @ColumnName = ColumnName
			FROM #IndexScript
			WHERE IndexName = @IndexNameOrig AND IndID = @IndID AND IndKey = @IndKey
		
			IF @ColumnName IS NOT NULL AND @ColumnName <> @OldColumnName
			BEGIN
				SET @SQLIndex = @SQLIndex
					+ '[' + @ColumnName + '],'
			END
		
			SET @OldColumnName = @ColumnName
			SET @IndKey = @IndKey + 1 
		END

		IF RIGHT(@SQLIndex,1) = ','
			SET @SQLIndex = LEFT(@SQLIndex, LEN(@SQLIndex) - 1)

		SET @SQLIndex = @SQLIndex + ')'

		--Add file group name
		IF @GroupName is not null
			SET @SQLIndex = @SQLIndex
				+ ' ON [' + @GroupName + ']'

		SET @SQLIndex = @SQLIndex
			+ CHAR(10) + 'GO' + CHAR(10)

		FETCH NEXT FROM IndexName INTO @IndexName, @IndID, @UniqueIndex
	END

	CLOSE IndexName
	DEALLOCATE IndexName
	SET @Query = @Query + @SQLIndex
	SET @SQLIndex = replace(@SQLIndex,CHAR(10) + 'GO', CHAR(10))
END
--End building index script.

DROP TABLE #IndexScript

IF @NoTable = 0 AND @PKOnly = 0
	DROP TABLE #TableScript

IF @DisplayScript = 1
	PRINT @Query

IF @Exec = 1
BEGIN
	--This code needed to remark out all GO commands before executing the code in the variable @Query
	SET @Query = REPLACE(@Query,CHAR(10) + 'GO', CHAR(10) + '--GO')

	Exec (@Query)
END

RETURN 0

Err:
	RETURN @err

GO



