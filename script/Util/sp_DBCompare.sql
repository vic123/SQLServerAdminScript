/*
By: marco.casamento 

This simple script make a comparison between two given database. 
It compare: The table present in both database
            The data type, lenght, nullability, precision for each table.
            The object present in both database.
The StoredProc is able to compare database across different server, simple make the server a "Linked server" and use the notation SERVER.DB (Es. EXEC sp_DBCompare 'SERVER1.DB1','SERVER2.DB2') to supply parameter to SP. For any question about the script you can contact me!
Have fun! NOTE: The script actually run only on SqlServer 2000, not SqlServer 7, because it compare the collation at column level and SqlServer don't manage it. 
*/

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO



IF OBJECT_ID('sp_DBCompare') IS NOT NULL  
  DROP Procedure sp_DBCompare
GO

CREATE             Procedure sp_DBCompare
(		@DB1 varchar (255),
		@DB2 varchar (255)
		)
AS
--exec sp_DBCompare 'DB1', 'DB2'
--SELECT * FROM tempdb.dbo.ObjectLacking

BEGIN
	DECLARE @Time datetime
	SET @Time = GetDate ()
	SET ANSI_NULLS ON

	SET ANSI_WARNINGS ON

	SET NOCOUNT ON
	if exists (select * from tempdb.dbo.sysobjects where id = object_id('tempdb.dbo.TableLacking'))
		TRUNCATE table tempdb.dbo.TableLacking
		
	IF not exists (select * from tempdb.dbo.sysobjects where id = object_id('tempdb.dbo.TableLacking'))
	BEGIN
		CREATE TABLE tempdb.dbo.TableLacking (
		Name1 varchar (255),
		Type1 varchar (5),
		Name2 varchar (255),
		Type2 varchar (5)
		) 
	END

	if exists (select * from tempdb.dbo.sysobjects where id = object_id('tempdb.dbo.ObjectLacking'))
		TRUNCATE table tempdb.dbo.ObjectLacking
		
	IF not exists (select * from tempdb.dbo.sysobjects where id = object_id('tempdb.dbo.ObjectLacking'))
	BEGIN
		CREATE TABLE tempdb.dbo.ObjectLacking (
		Name1 varchar (255),
		Type1 varchar (5),
		Name2 varchar (255),
		Type2 varchar (5)
		) 
	END

	if exists (select * from tempdb.dbo.sysobjects where id = object_id('tempdb.dbo.TableDiff'))
		TRUNCATE table tempdb.dbo.TableDiff
		
	IF not exists (select * from tempdb.dbo.sysobjects where id = object_id('tempdb.dbo.TableDiff'))
	BEGIN
		CREATE TABLE tempdb.dbo.TableDiff (
			NomeTable1 varchar(255) NULL,
			Column_name1 varchar (255) NULL ,
			Type1 varchar (255) NULL ,
			Computed1 tinyint NULL ,
			Lenght1 int NULL ,
			Prec1 varchar (255) NULL ,
			Scale1 varchar (255) NULL ,
			Nullable1 tinyint NULL ,
			Collation1 varchar (255) NULL,
			NomeTable2 varchar(255) NULL,
			Column_name2 varchar (255) NULL ,
			Type2 varchar (255) NULL ,
			Computed2 tinyint NULL ,
			Lenght2 int NULL ,
			Prec2 varchar (255) NULL ,
			Scale2 varchar (255) NULL ,
			Nullable2 tinyint NULL ,
			Collation2 varchar (255) NULL 
		) 
	END

	if exists (select * from tempdb.dbo.sysobjects where id = object_id('tempdb.dbo.ObjForCursor'))
		TRUNCATE table tempdb.dbo.ObjForCursor
		
	IF not exists (select * from tempdb.dbo.sysobjects where id = object_id('tempdb.dbo.ObjForCursor'))
	BEGIN
		CREATE TABLE tempdb.dbo.ObjForCursor (
		TableName varchar (255)
		) 
	END
	if exists (select * from tempdb.dbo.sysobjects where id = object_id('tempdb.dbo.Table1'))
		TRUNCATE table tempdb.dbo.Table1
		
	IF not exists (select * from tempdb.dbo.sysobjects where id = object_id('tempdb.dbo.Table1'))
	BEGIN
		CREATE TABLE tempdb.dbo.Table1 (
			Table_name varchar(255) NOT NULL,
			Column_name varchar (255) NOT NULL ,
			Type varchar (255) NOT NULL ,
			Computed tinyint NOT NULL ,
			Lenght int NOT NULL ,
			Prec varchar (255) NULL ,
			Scale varchar (255) NULL ,
			Nullable tinyint NOT NULL ,
			Collation varchar (255) NULL 
		) 
	END

	if exists (select * from tempdb.dbo.sysobjects where id = object_id('tempdb.dbo.Table2'))
		TRUNCATE table tempdb.dbo.Table2
		
	IF not exists (select * from tempdb.dbo.sysobjects where id = object_id('tempdb.dbo.Table2'))
	BEGIN
		CREATE TABLE tempdb.dbo.Table2 (
			Table_name varchar(255) NOT NULL,
			Column_name varchar (255) NOT NULL ,
			Type varchar (255) NOT NULL ,
			Computed tinyint NOT NULL ,
			Lenght int NOT NULL ,
			Prec varchar (255) NULL ,
			Scale varchar (255) NULL ,
			Nullable tinyint NOT NULL ,
			Collation varchar (255) NULL 
		) 
	END

	DECLARE @Sql varchar(8000)
	
	SELECT @Sql = 
	'INSERT INTO tempdb.dbo.TableLacking (Name1, Type1, Name2, Type2)
	SELECT 	U1.name + ''.'' + T1.name, T1.type, 
			U2.name + ''.'' + T2.name, T2.type 
	FROM ' + @DB1 + '.dbo.sysobjects T1 
		INNER JOIN ' + @DB1 + '.dbo.sysusers U1 ON T1.uid = U1.uid
	FULL OUTER JOIN '+ @DB2 + '.dbo.sysobjects T2
		INNER JOIN ' + @DB2 + '.dbo.sysusers U2 ON T2.uid = U2.uid				
	ON T1.name = T2.name AND T1.type = T2.type AND U1.name = U2.name
	WHERE (T1.name is null or T2.name is null)
		AND (T1.type = ''U'' OR T2.type = ''U'')
	ORDER By 1,2'

	EXEC (@Sql)
	
	IF (SELECT COUNT(*) FROM tempdb.dbo.TableLacking) > 0 
	BEGIN
		SELECT * FROM tempdb.dbo.TableLacking
		PRINT 'Some table are lacking between databases ' + @DB1 + ' and ' + @DB2 
		PRINT 'Please check the tempdb.dbo.TableLacking and synchronize it'
	END

	SELECT @Sql = '	INSERT INTO tempdb.dbo.ObjForCursor (TableName)
					SELECT U1.name + ''.'' + T1.name 
					FROM ' + @DB1 + '.dbo.sysobjects T1 
						INNER JOIN ' + @DB1 + '.dbo.sysusers U1 ON T1.uid = U1.uid
					INNER JOIN ' + @DB2 + '.dbo.sysobjects T2
						INNER JOIN ' + @DB2 + '.dbo.sysusers U2 ON T2.uid = U2.uid				
					ON T1.name = T2.name AND T1.type = T2.type AND U1.name = U2.name
				WHERE 
					(T1.type = ''U'' OR T2.type = ''U'')
				ORDER BY 1'
	EXEC (@Sql)
	
	DECLARE @TableName varchar(255), 
			@Sql4Proc varchar(7000),
			@Object1 varchar(250),
			@Object2 varchar(250)

	DECLARE CurTable CURSOR STATIC FOR 
		SELECT TableName FROM tempdb.dbo.ObjForCursor

	OPEN CurTable
	FETCH NEXT FROM CurTable INTO @TableName
	WHILE @@fetch_status <> -1
	BEGIN
	SELECT @Object1 = @DB1 + '.' + @TableName, @Object2 = @DB2 + '.' + @TableName
	/*
		SELECT @Sql4Proc = 
		'INSERT INTO tempdb.dbo.TableDiff 
		 EXEC sp_TableCompare ''' + @DB1 + '.' + @TableName + ''', ''' + @DB2+ '.' + @TableName + ''''

		EXEC (@Sql4Proc)
	*/
	BEGIN
		
			DECLARE @numtypes varchar(80), 
					@objid1 int, 
					@objid2 int
		
			SET	@numtypes = 'tinyint,smallint,decimal,int,real,money,float,numeric,smallmoney'
			SET @TableName = PARSENAME(@TableName,1)
			SELECT @Sql=	
			'INSERT INTO tempdb.dbo.Table1 (Table_name, Column_name, Type, Computed, Lenght, Prec, Scale, Nullable,	Collation)
			SELECT	''' + @TableName + ''', C.name, T.name, C.iscomputed, convert(int, C.length), 
					case when charindex(T.name, ''' + @numtypes + ''') > 0
					 		then C.prec else 0 end,
					case when charindex(T.name, ''' + @numtypes + ''') > 0
						  then convert(char(5),OdbcScale(C.xtype,C.xscale))
					else ''     '' end,
					C.isnullable, C.collation
			FROM ' + @DB1 + '.dbo.syscolumns C inner join ' + @DB1 + '.dbo.systypes T 
					ON	T.xtype = C.xtype AND T.usertype = C.usertype
				INNER JOIN ' + @DB1 + '.dbo.sysobjects O
					ON O.id = C.id
				INNER JOIN ' + @DB1 + '.dbo.sysusers U
					ON O.uid = U.uid		
			WHERE O.name  = ''' + @TableName + ''' and U.name = ''' + PARSENAME(@Object1, 2) + '''and number = 0 ORDER BY colid'
--			SELECT @Sql	
			EXEC (@Sql)
			
			SELECT @Sql=	
			'INSERT INTO tempdb.dbo.Table2 (Table_name, Column_name, Type, Computed, Lenght, Prec, Scale, Nullable,	Collation)
			SELECT	''' + @TableName + ''', C.name, T.name, C.iscomputed, convert(int, C.length), 
					case when charindex(T.name, ''' + @numtypes + ''') > 0
					 		then C.prec else 0 end,
					case when charindex(T.name, ''' + @numtypes + ''') > 0
						  then convert(char(5),OdbcScale(C.xtype,C.xscale))
					else ''     '' end,
					C.isnullable, C.collation
			FROM ' + @DB2 + '.dbo.syscolumns C inner join ' + @DB2 + '.dbo.systypes T 
					ON	T.xtype = C.xtype AND T.usertype = C.usertype
				INNER JOIN ' + @DB2 + '.dbo.sysobjects O
					ON O.id = C.id
				INNER JOIN ' + @DB2 + '.dbo.sysusers U
					ON O.uid = U.uid		
			WHERE O.name  = ''' + @TableName + ''' and U.name = ''' + PARSENAME(@Object2, 2) + '''and number = 0 ORDER BY colid'
--			SELECT @Sql
			EXEC (@Sql)
		
			INSERT INTO tempdb.dbo.TableDiff
			SELECT * FROM tempdb.dbo.Table1 T1 FULL OUTER JOIN tempdb.dbo.Table2 T2
				ON T1.Column_name = T2.Column_name
			WHERE (T1.Column_name is null or T2.Column_name is null)
				OR (T1.Type <> T2.Type) OR (T1.Lenght <> T2.Lenght)
				OR (T1.Prec <> T2.Prec) OR (T1.Nullable <> T2.Nullable)
				OR (T1.Collation <> T2.Collation) OR (T1.Scale <> T2.Scale)

			TRUNCATE table tempdb.dbo.Table1
			TRUNCATE table tempdb.dbo.Table2

		END



	FETCH NEXT FROM CurTable INTO @TableName
	END
	CLOSE CurTable



	DEALLOCATE CurTable
	
	IF (SELECT COUNT(*) FROM tempdb.dbo.TableDiff) > 0 
	BEGIN
		SELECT * FROM tempdb.dbo.TableDiff
		PRINT 'Some table are different between databases ' + @DB1 + ' and ' + @DB2 
		PRINT 'Please check the tempdb.dbo.TableDiff and synchronize it'
	END


	SELECT @Sql = 	
	'INSERT INTO tempdb.dbo.ObjectLacking (Name1, Type1, Name2, Type2)
	SELECT 	U1.name + ''.'' + T1.name, T1.type, 
			U2.name + ''.'' + T2.name, T2.type 
	FROM ' + @DB1 + '.dbo.sysobjects T1 
		INNER JOIN ' + @DB1 + '.dbo.sysusers U1 ON T1.uid = U1.uid
	FULL OUTER JOIN '+ @DB2 + '.dbo.sysobjects T2
		INNER JOIN ' + @DB2 + '.dbo.sysusers U2 ON T2.uid = U2.uid				
	ON T1.name = T2.name AND T1.type = T2.type AND U1.name = U2.name
	WHERE (T1.name is null or T2.name is null)
		AND (T1.type IN (''C'',''FN'',''IF'',''P'',''TF'',''TR'',''V'',''X'',''PK'',''F'', ''UK'') 
				OR T2.type IN (''C'',''FN'',''IF'',''P'',''TF'',''TR'',''V'',''X'', ''PK'', ''F'', ''UK'') )'

	
	EXEC (@Sql)
	
	SELECT @Sql = 
	'INSERT INTO tempdb.dbo.ObjectLacking (Name1, Type1, Name2, Type2)
	SELECT  U1.name + ''.'' + T1.name + ''.'' + S1.name, ''IX'', U2.name + ''.'' + T2.name + ''.'' + S2.name, ''IX''
	FROM ' + @DB1 + '.dbo.sysobjects T1 
		INNER JOIN ' + @DB1 + '.dbo.sysindexes S1 	ON T1.id = S1.id 
		INNER JOIN ' + @DB1 + '.dbo.sysusers U1 	ON T1.uid = U1.uid
	FULL OUTER JOIN ' + @DB2 + '.dbo.sysobjects T2 
		INNER JOIN ' + @DB2 + '.dbo.sysindexes S2	ON T2.id = S2.id 
		INNER JOIN ' + @DB2 + '.dbo.sysusers U2		ON T2.uid = U2.uid
	ON S1.name = S2.name
	WHERE (S1.name is null or S2.name is null )
	AND (S1.indid between  0 and  255 and (S1.status & 64)=0 AND S1.keys is not null
			OR 
		  S2.indid between  0 and  255 and (S2.status & 64)=0 AND S2.keys is not null)'


--	EXEC (@Sql)

	IF (SELECT COUNT(*) FROM tempdb.dbo.ObjectLacking) > 0 
	BEGIN
		SELECT * FROM tempdb.dbo.ObjectLacking ORDER BY 1,2,3,4
		PRINT 'Some object are lacking between databases ' + @DB1 + ' and ' + @DB2 
		PRINT 'Please check the tempdb.dbo.ObjectLacking and synchronize it'
	END
	PRINT 'Execution time: ' + CONVERT(varchar, DATEDIFF(ms,@Time, GetDate()) )+ ' ms'
	SET NOCOUNT OFF	
END
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO







