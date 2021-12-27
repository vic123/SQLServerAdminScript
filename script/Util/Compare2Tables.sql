IF Exists(Select id from sysobjects where id = object_id('sp_Compare2Tables') and type ='P')
	Drop Procedure sp_Compare2Tables
GO
CREATE PROC sp_Compare2Tables
@TableName1 sysName ,  
@TableName2 sysName ,  
@ListDiff bit = 1 ,  
@StructureOnly bit =0 ,  
@CheckTimeStamp bit =0 ,  
@Verbose bit =0 ,  
@Fields varchar(4000)=''

/*
DROP TABLE #TblDisplay_Diff
CREATE TABLE #TblDisplay_Diff (
	[TempDiffId] [numeric] (18, 0) IDENTITY (1, 1) NOT NULL, 
	Year int, 
	Month int,
	Table_Name sysname, 
	[mDay] [numeric] (18, 0) NULL, 
	[Customer] [varchar] (255) COLLATE Latin1_General_CI_AS NULL, 
	[Provider] [varchar] (255) COLLATE Latin1_General_CI_AS NULL, 
	[Destination] [varchar] (255) COLLATE Latin1_General_CI_AS NULL, 
	[DailyMinutes] [float] NULL, 
	[CustomerID] [numeric] (18, 0) NULL, 
	[Rate_ID] [numeric] (18, 0) NULL
) 

DECLARE @month int, @Year int 
SET @Year = 2006
SET @month = 1
DECLARE @tbl_name sysname, @tmp_tbl_name sysname
WHILE @month < 13 BEGIN
	SELECT @tbl_name = 'Summary.dbo.TblDisplay' + convert(varchar, @month) + convert(varchar, @Year),
		@tmp_tbl_name = 'Summary.dbo.TblDisplay' + convert(varchar, @month) + convert(varchar, @Year) + '_CompareCheckTemp'
	INSERT INTO #TblDisplay_Diff (Table_Name, mDay, Customer, Provider, Destination, DailyMinutes, CustomerID, Rate_ID) 
	exec sp_Compare2Tables @TableName1 = @tbl_name, 
				@TableName2 = @tmp_tbl_name, 
				@Fields = 'mDay, Customer, Provider, Destination, DailyMinutes, CustomerID, Rate_ID',
				@Verbose = 0
	UPDATE #TblDisplay_Diff SET Year = @Year, Month = @month, Table_name = '...' + substring(Table_name, 23, 100)
		 WHERE Year IS NULL
	SET  @month = @month + 1
END

DROP TABLE #TblDisplay_Diff_EQ
SELECT * INTO #TblDisplay_Diff_EQ
	FROM #TblDisplay_Diff d1
	WHERE EXISTS (SELECT * FROM #TblDisplay_Diff d2 
			WHERE d1.Table_Name <> d2.Table_Name
			AND d1.mDay = d2.mDay
			AND d1.DailyMinutes = d2.DailyMinutes
			AND d1.CustomerID = d2.CustomerID
			AND d1.Rate_ID = d2.Rate_ID
	)

SELECT Year, Month, mDay, CustomerID, Rate_ID, DailyMinutes, Table_name, Customer, Provider, Destination
	FROM #TblDisplay_Diff_EQ 
	ORDER BY Year, Month, mDay, CustomerID, Rate_ID, DailyMinutes, Table_name, Customer, Provider, Destination 

SELECT Year, Month, mDay, CustomerID, Rate_ID, DailyMinutes, Table_name, Customer, Provider, Destination
	FROM #TblDisplay_Diff d
	WHERE NOT EXISTS (SELECT * FROM #TblDisplay_Diff_EQ eq WHERE eq.TempDiffId = d.TempDiffId)
	ORDER BY Year, Month, mDay, CustomerID, Rate_ID, DailyMinutes, Table_name, Customer, Provider, Destination 

SELECT DISTINCT CustomerID, Customer FROM #TblDisplay_Diff_EQ eq1
	WHERE EXISTS (SELECT * FROM #TblDisplay_Diff_EQ eq2  
			WHERE eq1.Table_Name <> eq2.Table_Name
			AND eq1.mDay = eq2.mDay
			AND eq1.DailyMinutes = eq2.DailyMinutes
			AND eq1.CustomerID = eq2.CustomerID
			AND eq1.Rate_ID = eq2.Rate_ID
			AND isNull(eq1.Customer, 'null') <> isNull(eq2.Customer, 'null')
		)
ORDER BY CustomerID, Customer

SELECT DISTINCT Rate_Id, Destination FROM #TblDisplay_Diff_EQ eq1 
	WHERE EXISTS (SELECT * FROM #TblDisplay_Diff_EQ eq2  
			WHERE eq1.Table_Name <> eq2.Table_Name
			AND eq1.mDay = eq2.mDay
			AND eq1.DailyMinutes = eq2.DailyMinutes
			AND eq1.CustomerID = eq2.CustomerID
			AND eq1.Rate_ID = eq2.Rate_ID
			AND isNull(eq1.Destination, 'null') <> isNull(eq2.Destination, 'null')
		)
ORDER BY Rate_Id, Destination

SELECT DISTINCT Table_name, Provider FROM #TblDisplay_Diff_EQ eq1
	WHERE EXISTS (SELECT * FROM #TblDisplay_Diff_EQ eq2  
			WHERE eq1.Table_Name <> eq2.Table_Name
			AND eq1.mDay = eq2.mDay
			AND eq1.DailyMinutes = eq2.DailyMinutes
			AND eq1.CustomerID = eq2.CustomerID
			AND eq1.Rate_ID = eq2.Rate_ID
			AND isNull(eq1.Provider, 'null') <> isNull(eq2.Provider, 'null')
		)



--SELECT * FROM #TblDisplay_Diff ORDER BY Year, Month, mDay, Customer, Provider, Destination, DailyMinutes, CustomerID, Rate_ID, Table_name
  
 sp_Compare2Tables 
                         
 The SP compares the structure & data in 2 tables.               
 Tables could be from different servers, different databases or different schemas.        
  
 Parameters:                      
 1.  @TableName1 - Name of the table to be checked.              
 2.  @TableName2 - Name of the table to be checked.              
 3.  @ListDiff - Bit to list the differences               
 4.  @StructureOnly - Bit to compare only the structure             
 5.  @CheckTimeStamp - Bit to check the timestampfields too            
 6.  @Verbose - Bit To Print the Queries Used               
 7.  @Fields - Optional List of fields which to be checked             
                        
 Assumptions:  The length of the field list and other dynamic strings should not exceed 8000 characters   
     Both tables have primary keys               
     Primary key combination is same for both tables           
 Paramenter 1, 2: Table name (With optional server name, database name, Schema name seperated with .)    
     Eg. Preethi.Inventory.Dbo.TranHeader, Preethi.Test.dbo.Tran         
         Any of the first 3 parts could be omitted.            
         Inventory.DBO.TranHeader, INV.TranHeader and TranHeader are valid       
    Note:                   
     When using multi part name include them in Single Quotations       
     (Eg. 'Inventory.DBO.TranHeader',  'INV.TranHeader')         
 Parameter 3: List the differences                 
     IF True it will list all the different fields (in case of structural difference)    
     or all the different entries (in case of data differences)        
     Default is 1 (List the differences)            
 Parameter 4: Compare only the structure               
     Default=0 (Compare structure & data -if structure is same.)        
 Parameter 5: Check timestamp fields                 
     Default =0 (Ignore timestamp columns)            
 Parameter 6: Verbose Mode (Print the queries too             
     Default =0 (Donot print the queries)            
 Parameter 7: List of fields which to be checked              
     If omitted, all fields will be checked. if parameter 5 is set to 0 timestamp field will be omitted.
     If specified, checktimestamp value be ignored
  
       Created by G.R.Preethiviraj Kulasingham   
       Written on  : August  17, 2002          
       Modified on : february 19, 2004          
  
*/
  
AS  
  
SET NOCOUNT ON  
SET ANSI_WARNINGS ON  
SET ANSI_NULLS ON  
  
declare @SQLStr nvarchar(4000), @OrderBy varchar(4000), @ConditionList varchar(4000), @FieldList varchar(4000)  
Declare @SQL1 varchar(8000), @SQL2 varchar(8000), @SQL3 varchar(8000), @SQL4 varchar(8000)
declare @SvrName1 sysname, @DBName1 sysname, @Schema1 Sysname, @Table1 Sysname   
Declare @SvrName2 sysname, @DBName2 sysname, @Schema2 sysname, @Table2 sysname  
declare @Int1 int, @Int2 int, @Int3 int, @Int4 int   
--Declare @TimeStamp bit  
  
  
--set @Table1 = @TableName1  
set @SvrName1 = ISNULL(PARSENAME(@TableName1,4), @@SERVERNAME)  
Set @DBName1 = ISNULL(PARSENAME(@TableName1,3), DB_NAME())  
set @Schema1 = ISNULL(PARSENAME(@TableName1,2), CURRENT_USER)  
set @Table1= PARSENAME(@TableName1,1)  
  
set @SvrName2 = ISNULL(PARSENAME(@TableName2,4), @@SERVERNAME)  
Set @DBName2 = ISNULL(PARSENAME(@TableName2,3), DB_NAME())  
set @Schema2 = ISNULL(PARSENAME(@TableName2,2), CURRENT_USER)  
set @Table2 = PARSENAME(@TableName2,1)  
  
/*
Select @SvrName1 as [Server], @DBName1 [Data Base], @Schema1 [Schema], @Table1 [Table]
union 
Select @SvrName2, @DBName2, @Schema2, @Table2
*/
-- Check for the existance of specified Servers, databases, schemas and tables  
  
IF @SvrName1<>@@SERVERNAME  
 IF not exists (select * FROM master.dbo.sysservers where srvname = @SvrName1)  
 BEGIN  
  PRINT 'There is no linked server named '+@SvrName1+'. Termination of Procedure.'  
  RETURN   
 END  
Declare @Name sysname
  
select @Name=null, @SQLStr = N'Select @Name=Name FROM ['+@SvrName1+'].master.dbo.sysdatabases where name ='''+ @DBName1+''''  
EXECUTE sp_ExecuteSQL @SQLStr, N'@Name sysname output', @Name output    
IF @Name is NULL 
BEGIN  
 PRINT 'There is no database named '+@DBName1+'. Termination of Procedure.'  
 RETURN   
END  
  
select @Name=null, @SQLStr = N'Select @Name=name FROM ['+@SvrName1+'].['+@DBName1+'].dbo.sysusers where name ='''+ @Schema1+''''  
EXECUTE sp_ExecuteSQL @SQLStr, N'@Name sysname output', @Name output    
IF @Name is NULL 
BEGIN  
 PRINT 'There is no schema named '+@Schema1+' in the specified Database. Termination of Procedure.'  
 RETURN   
END  
  
select @Name=null, @SQLStr = N'Select @Name=o.Name FROM  ['+@SvrName1+'].['+@DBName1+'].dbo.sysobjects O, ['+@SvrName1+'].['+@DBName1+'].dbo.sysusers U Where O.uid=U.Uid and U.Name =''' + @Schema1 +''' and O.name=''' +@Table1+''' and xtype in (''U'', ''V'')'  
EXECUTE sp_ExecuteSQL @SQLStr, N'@Name sysname output', @Name output    
IF @Name is NULL 
BEGIN  
 PRINT 'There is no Table named '+@Table1+'. END of work.'  
 RETURN   
END  
  
  
  
IF @SvrName2<>@@SERVERNAME  
 IF not exists (select * FROM master.dbo.sysservers where srvname = @SvrName2)  
 BEGIN  
  PRINT 'There is no linked server named '+@SvrName2+'. Termination of Procedure.'  
  RETURN   
 END  
  
select @Name=null, @SQLStr = 'Select @Name=name FROM ['+@SvrName2+'].master.dbo.sysdatabases where name ='''+ @DBName2+''''  
EXECUTE sp_ExecuteSQL @SQLStr, N'@Name sysname output', @Name output    
IF @Name is NULL 
BEGIN  
 PRINT 'There is no database named '+@DBName2+'. Termination of Procedure.'  
 RETURN   
END  
  
select @Name=null, @SQLStr = 'Select @Name=name FROM ['+@SvrName2+'].['+@DBName2+'].dbo.sysusers where name ='''+ @Schema2+''''  
EXECUTE sp_ExecuteSQL @SQLStr, N'@Name sysname output', @Name output    
IF @Name is NULL 
BEGIN  
 PRINT 'There is no schema named '+@Schema2+'in the specified Database. Termination of Procedure.'  
 RETURN   
END  
  
select @Name=null, @SQLStr = 'Select @Name=o.name FROM  ['+@SvrName2+'].['+@DBName2+'].dbo.sysobjects O, ['+@SvrName2+'].['+@DBName2+'].dbo.sysusers U Where O.uid=U.Uid and U.Name =''' + @Schema2 +''' and O.name=''' +@Table2+''' and xtype in (''U'', ''V'')'  
EXECUTE sp_ExecuteSQL @SQLStr, N'@Name sysname output', @Name output    
IF @Name is NULL 
BEGIN  
 PRINT 'There is no Table named '+@Table2+'. END of work.'  
 RETURN   
END  
  
-- Check whether both tables are same.  
IF (@SvrName1 + @DbName1 + @Schema1 + @Table1)=(@SvrName2 + @DbName2 + @Schema2 + @Table2)  
BEGIN  
 PRINT 'Both Tables  should be different. Termination of Procedure'  
 RETURN  
END  
  
-- Check whether the structure of both tables are same.  
-- Method:  Get the tables with column data   
--   Select the no of rows in each and in union.  
--   If both are same they are same  
Print '--Comparing the structure started at '+Convert(varchar(35), GetDate(),109)  
Create Table #TableColumns   
(      
 TABLE_SERVER sysname NOT NULL,      
 TABLE_CATALOG sysname NOT NULL,      
 TABLE_SCHEMA sysname NOT NULL,      
 TABLE_NAME sysname NOT NULL,      
 COLUMN_NAME sysname NOT NULL,      
 ORDINAL_POSITION smallint NOT NULL,    
 IS_NULLABLE bit NOT NULL,  
 DATA_TYPE sysname NOT NULL,      
 CHARACTER_MAXIMUM_LENGTH int NULL,      
 CHARACTER_OCTET_LENGTH int NULL,      
 NUMERIC_PRECISION tinyint NULL,      
 NUMERIC_PRECISION_RADIX smallint NULL,      
 NUMERIC_SCALE int NULL,       
 DATETIME_PRECISION smallint NULL  
   
)      
Create Table #Table_Index    
(  
 ColumnName sysname NOT NULL,  
 OrderID   Int NOT NULL  
)  
   
Create Table #ROWCount_Table  
(  
 Int1 int NOT NULL,   
 Int2 int NULL,   
 Int3 int NULL,  
 Int4 int NULL  
)  
  
IF @Verbose=1   
 PRINT '  
Create Table #TableColumns   
(      
 TABLE_SERVER sysname NOT NULL,      
 TABLE_CATALOG sysname NOT NULL,      
 TABLE_SCHEMA sysname NOT NULL,      
 TABLE_NAME sysname NOT NULL,      
 COLUMN_NAME sysname NOT NULL,      
 ORDINAL_POSITION smallint NOT NULL,    
 IS_NULLABLE bit NOT NULL,  
 DATA_TYPE sysname NOT NULL,      
 CHARACTER_MAXIMUM_LENGTH int NULL,      
 CHARACTER_OCTET_LENGTH int NULL,      
 NUMERIC_PRECISION tinyint NULL,      
 NUMERIC_PRECISION_RADIX smallint NULL,      
 NUMERIC_SCALE int NULL,       
 DATETIME_PRECISION smallint NULL  
   
)      
Create Table #Table_Index    
(  
 ColumnName sysname NOT NULL,  
 OrderID   Int NOT NULL  
)  
   
Create Table #ROWCount_Table  
(  
 Int1 int NOT NULL,   
 Int2 int NULL,   
 Int3 int NULL,  
 Int4 int NULL  
)  
'  
  
SET @SQLStr = 'Insert into  #TableColumns   
SELECT '''+@SvrName1+''', '''+@DBName1 +''',      
 usr.name, obj.name,      
 Col.name,      
 col.colid,      
 col.isnullable,   
 spt_dtp.LOCAL_TYPE_NAME,      
 convert(int, OdbcPrec(col.xtype, col.length, col.xprec)  + spt_dtp.charbin),      
 convert(int, spt_dtp.charbin +   
     case when spt_dtp.LOCAL_TYPE_NAME in (''nchar'', ''nvarchar'', ''ntext'')  
    then  2*OdbcPrec(col.xtype, col.length, col.xprec)   
    else  OdbcPrec(col.xtype, col.length, col.xprec)   
     end),      
 nullif(col.xprec, 0),      
 spt_dtp.RADIX,      
 col.scale,      
 spt_dtp.SQL_DATETIME_SUB  
FROM ['+@SvrName1+'].['+@DBName1+'].dbo.sysobjects obj,  
 ['+@SvrName1+'].master.dbo.spt_datatype_info spt_dtp,  
 ['+@SvrName1+'].['+@DBName1 +'].dbo.systypes typ,  
 ['+@SvrName1+'].['+@DBName1 +'].dbo.sysusers usr,  
 ['+@SvrName1+'].['+@DBName1 +'].dbo.syscolumns col       
WHERE  
 obj.id = col.id  
     AND obj.uid=usr.uid   
 AND typ.xtype = spt_dtp.ss_dtype  
 AND (spt_dtp.ODBCVer is null or spt_dtp.ODBCVer = 2)  
 AND obj.xtype in (''U'', ''V'')  
 AND col.xusertype = typ.xusertype  
 AND (spt_dtp.AUTO_INCREMENT is null or spt_dtp.AUTO_INCREMENT = 0)   
 AND obj.name =''' + @Table1+ ''' and usr.name ='''+@Schema1+''''  
EXECUTE sp_ExecuteSQL @SQLStr   

IF @Verbose=1   
 Print @SQLStr  
  
set @SQLStr = 'Insert into  #TableColumns   
SELECT '''+@SvrName2+''', '''+@DbName2 +''',      
 usr.name, obj.name,      
 Col.name,      
 col.colid,      
 col.isnullable,   
 spt_dtp.LOCAL_TYPE_NAME,      
 convert(int, OdbcPrec(col.xtype, col.length, col.xprec)  + spt_dtp.charbin),      
 convert(int, spt_dtp.charbin +   
     case when spt_dtp.LOCAL_TYPE_NAME in (''nchar'', ''nvarchar'', ''ntext'')  
    then  2*OdbcPrec(col.xtype, col.length, col.xprec)   
    else  OdbcPrec(col.xtype, col.length, col.xprec)   
     end),      
 nullif(col.xprec, 0),      
 spt_dtp.RADIX,      
 col.scale,      
 spt_dtp.SQL_DATETIME_SUB  
FROM ['+@SvrName2+'].['+@DBName2+'].dbo.sysobjects obj,  
 ['+@SvrName2+'].master.dbo.spt_datatype_info spt_dtp,  
 ['+@SvrName2+'].['+@DBName2 +'].dbo.systypes typ,  
 ['+@SvrName2+'].['+@DBName2 +'].dbo.sysusers usr,  
 ['+@SvrName2+'].['+@DBName2 +'].dbo.syscolumns col       
WHERE  
 obj.id = col.id  
     AND obj.uid=usr.uid   
 AND typ.xtype = spt_dtp.ss_dtype  
 AND (spt_dtp.ODBCVer is null or spt_dtp.ODBCVer = 2)  
 AND obj.xtype in (''U'', ''V'')  
 AND col.xusertype = typ.xusertype  
 AND (spt_dtp.AUTO_INCREMENT is null or spt_dtp.AUTO_INCREMENT = 0)   
 AND obj.name =''' + @Table2+ ''' and usr.name ='''+@Schema2+''''  
  
EXECUTE sp_ExecuteSQL @SQLStr   
IF @Verbose=1   
 Print @SQLStr  

IF @Fields<>''  
 Delete From #TableColumns Where CharIndex(COLUMN_NAME, @Fields)=0  
  
IF EXISTS(SELECT COLUMN_NAME,   
   DATA_TYPE,  
   CHARACTER_MAXIMUM_LENGTH,  
   CHARACTER_OCTET_LENGTH,  
   NUMERIC_PRECISION,  
   NUMERIC_PRECISION_RADIX,  
   NUMERIC_SCALE,  
   DATETIME_PRECISION,  
   COUNT(*) AS  NUMBERS   
  FROM #TableColumns   
  GROUP BY COLUMN_NAME,   
   DATA_TYPE,  
   CHARACTER_MAXIMUM_LENGTH,  
   CHARACTER_OCTET_LENGTH,  
   NUMERIC_PRECISION,  
   NUMERIC_PRECISION_RADIX,  
   NUMERIC_SCALE,  
   DATETIME_PRECISION  
  HAVING COUNT(*)=1)  
BEGIN  
 PRINT 'The Structure of the tables are different. Termination of Procedure.'  
 IF @ListDiff =1  
 SELECT A.*   
 FROM #TableColumns A,     
  (SELECT COLUMN_NAME,   
   DATA_TYPE,  
   CHARACTER_MAXIMUM_LENGTH,  
   CHARACTER_OCTET_LENGTH,  
   NUMERIC_PRECISION,  
   NUMERIC_PRECISION_RADIX,  
   NUMERIC_SCALE,  
   DATETIME_PRECISION,  
   COUNT(*) as NUMBERS   
  FROM #TableColumns   
  GROUP BY COLUMN_NAME,   
   DATA_TYPE,  
   CHARACTER_MAXIMUM_LENGTH,  
   CHARACTER_OCTET_LENGTH,  
   NUMERIC_PRECISION,  
   NUMERIC_PRECISION_RADIX,  
   NUMERIC_SCALE,  
   DATETIME_PRECISION  
  HAVING COUNT(*) =1) B  
 WHERE A.COLUMN_NAME = B.COLUMN_NAME AND   
  A.DATA_TYPE = B.DATA_TYPE AND  
  (ISNULL(A.CHARACTER_MAXIMUM_LENGTH,0)=ISNULL(B.CHARACTER_MAXIMUM_LENGTH,0)) AND  
  (ISNULL(A.NUMERIC_PRECISION, 0)=ISNULL(B.NUMERIC_PRECISION,0)) AND  
  (ISNULL(A.NUMERIC_PRECISION_RADIX, 0)=ISNULL(B.NUMERIC_PRECISION_RADIX,0)) AND  
  (ISNULL(A.NUMERIC_SCALE, 0)=ISNULL(B.NUMERIC_SCALE,0)) AND  
  (ISNULL(A.DATETIME_PRECISION, 0)=ISNULL(B.DATETIME_PRECISION,0))   
 ORDER BY A.ORDINAL_POSITION   
  
 DROP TABLE  #ROWCount_Table   
 DROP TABLE  #TableColumns  
 Print '--  Comparing the structure completed at '+Convert(varchar(35), GetDate(),109)  
 RETURN  
END  
ELSE 
 Print '--  Comparing the structure completed at '+Convert(varchar(35), GetDate(),109) 

IF @StructureOnly=1  
BEGIN  
 DROP TABLE  #ROWCount_Table   
 DROP TABLE  #TableColumns  
 RETURN  
END  
  
  
-----------------------------------------------------------------------------------------------  
--     Check for the presence of timestamp column          
-----------------------------------------------------------------------------------------------  
-- NOTE:  This First Method is a simple method to check Whether Both Tables are Identitical. --  
  
Print '--  Comparing the data started at '+Convert(varchar(35), GetDate(),109)  
SELECT @ConditionList='', @FieldList=''  
IF @Fields=''  
BEGIN  
 IF @CheckTimeStamp =1  
 BEGIN  
  IF NOT Exists(Select * FROM #TableColumns Where DATA_Type='TIMESTAMP')  
   SET @CheckTimeStamp=0  
 END  
 IF Exists(Select * FROM #TableColumns Where (DATA_Type<>'TIMESTAMP' or @CheckTimeStamp=1 ) and   
   TABLE_SERVER = @SvrName1 AND TABLE_CATALOG = @DBName1 and TABLE_Schema =@Schema1 and TABLE_Name= @Table1)  
   
 SELECT  @FieldList=@FieldList+',T.'+COLUMN_NAME,   
   @ConditionList= case IS_NULLABLE  
   WHEN 1 THEN @ConditionList +'AND((T.'+COLUMN_NAME+ '=A.'+COLUMN_NAME + ')OR(T.'+COLUMN_NAME+' IS NULL AND A.'+COLUMN_NAME+' IS NULL))'  
   ELSE @ConditionList +'AND(T.'+COLUMN_NAME+ '=A.'+COLUMN_NAME +')'   
   END  
 FROM  #TableColumns   
 WHERE TABLE_SERVER = @SvrName1 AND   
   TABLE_CATALOG = @DBName1 and   
   TABLE_Schema =@Schema1 and   
   TABLE_Name= @Table1 and   
   (DATA_Type<>'TIMESTAMP' or @CheckTimeStamp=1)  
 ORDER BY ORDINAL_POSITION  
END  
ELSE  
BEGIN  
 IF Exists(Select * FROM #TableColumns Where CharIndex(COLUMN_NAME, @Fields)>0 and   
   TABLE_SERVER = @SvrName1 AND TABLE_CATALOG = @DBName1 and TABLE_Schema =@Schema1 and TABLE_Name= @Table1)  
   
 SELECT  @FieldList=@FieldList+',T.'+COLUMN_NAME,   
   @ConditionList= case IS_NULLABLE  
   WHEN 1 THEN @ConditionList +'AND((T.'+COLUMN_NAME+ '=A.'+COLUMN_NAME + ')OR(T.'+COLUMN_NAME+' IS NULL AND A.'+COLUMN_NAME+' IS NULL))'  
   ELSE @ConditionList +'AND(T.'+COLUMN_NAME+ '=A.'+COLUMN_NAME +')'   
   END  
 FROM  #TableColumns   
 WHERE TABLE_SERVER = @SvrName1 AND   
   TABLE_CATALOG = @DBName1 and   
   TABLE_Schema =@Schema1 and   
   TABLE_Name= @Table1 and   
   CharIndex(COLUMN_Name, @Fields)>0  
 ORDER BY ORDINAL_POSITION  
END  
SET @FieldList= SUBSTRING(@FieldList, 2, LEN(@FieldList)-1)  
SET @ConditionList= SUBSTRING(@ConditionList, 4, LEN(@ConditionList)-3)  
SET @SQLStr='  
Insert Into #Table_Index (ColumnName, OrderID)  
select C.Name, k.keyno    
from ['+@SvrName1+'].['+@DbName1+'].dbo.sysobjects O,   
 ['+@SvrName1+'].['+@DbName1+'].dbo.sysindexes I,   
 ['+@SvrName1+'].['+@DbName1+'].dbo.sysindexkeys K,   
 ['+@SvrName1+'].['+@DbName1+'].dbo.syscolumns C,   
 ['+@SvrName1+'].['+@DbName1+'].dbo.sysusers U  
where O.uid = u.uid and u.name = '''+@Schema1+''' and O.name ='''+@Table1+''' and I.id = O.id and  
(I.status & 0x800) = 0x800 and I.indid = k.indid and O.id = k.id and k.colid =C.Colid and C.id =O.id  
'  
EXECUTE sp_ExecuteSQL @SQLStr   
IF @Verbose=1   
 Print @SQLStr  
  
SET @OrderBy =''  
IF Exists(Select * from #Table_Index )  
 Select @OrderBy = @OrderBy+',T.'+ColumnName From #Table_Index --(VB)Order By OrderID   
	 Where CharIndex(ColumnName, @Fields)<>0  Order By OrderID   --(VB-0609)
IF @OrderBy =''   --No Primary Index Found  
 SET @OrderBy =@FieldList  
ELSE  
 SET @OrderBy= SUBSTRING(@OrderBy, 2, LEN(@OrderBy)-1)  
  
  
  
--(VB) this index usage may need DBCC DBREINDEX to work 
SET @SQLStr='  
INSERT INTO #ROWCount_Table Select i.[rows],0,0, 0  
FROM ['+@SvrName1+'].['+@DBName1+'].dbo.sysindexes i,   
 ['+@SvrName1+'].['+@DBName1+'].dbo.sysObjects o,   
 ['+@SvrName1+'].['+@DBName1+'].dbo.sysusers u  
Where o.id=i.id and u.uid = o.uid and i.indid<2 and   
 u.name='''+@Schema1+''' and o.name ='''+@Table1+'''  
   
update #ROWCount_Table set Int2 =  
  (  
  Select i.[rows]   
  FROM ['+@SvrName2+'].['+@DBName2+'].dbo.sysindexes i,   
   ['+@SvrName2+'].['+@DBName2+'].dbo.sysObjects o,   
   ['+@SvrName2+'].['+@DBName2+'].dbo.sysusers u  
  Where o.id=i.id and u.uid = o.uid and i.indid<2 and  
   u.name='''+@Schema2+''' and o.name ='''+@Table2+''')  
  
Update #ROWCount_Table Set Int3=  
  (  
  Select Count(1) FROM   
   (  
   Select '+ @FieldList +'   
   FROM ['+@SvrName1+'].['+@DBName1+'].['+@Schema1+'].['+@Table1+'] T  
   UNION  
   Select '+ @FieldList +'   
   FROM ['+@SvrName2+'].['+@DBName2+'].['+@Schema2+'].['+@Table2+'] T  
   ) A  
  )  
Update #ROWCount_Table Set Int4=  
  (  
  Select Count(1) FROM   
   (  
   Select '+ @OrderBy +'   
   FROM ['+@SvrName1+'].['+@DBName1+'].['+@Schema1+'].['+@Table1+'] T   
   UNION  
   Select '+ @OrderBy +'   
   FROM ['+@SvrName2+'].['+@DBName2+'].['+@Schema2+'].['+@Table2+'] T   
   ) A  
  )'  
EXECUTE sp_ExecuteSQL @SQLStr   
IF @Verbose=1   
 Print @SQLStr  
   
Select @Int1=Int1, @Int2=Int2, @Int3=Int3, @Int4=Int4 FROM #ROWCount_Table   
IF @Int1=@Int3 and @Int2=@Int3   
BEGIN  
 PRINT '-- Both Tables are identitical.'  
 DROP TABLE  #ROWCount_Table   
 DROP TABLE  #TableColumns  
 Print '-- Comparing the data completed at '+Convert(varchar(35), GetDate(),109)  
 RETURN  
END  
  
PRINT '  
-- Both Tables are having different data  
------------------------------------------------------  
-- No. of records in '+@TableName1+ ' are '+Convert(Varchar(20), @Int1)+'.  
-- No. of records in '+@TableName2+ ' are '+Convert(Varchar(20), @Int2)+'.  
-- No. of records common in both are '+Convert(Varchar(20), @Int1+@int2-@Int3)+'.  
-- No. of unmatched records in '+@TableName1+ ' are '+Convert(Varchar(20),@int3-@Int2)+'.  
-- No. of unmatched records in '+@TableName2+ ' are '+Convert(Varchar(20),@int3-@Int1)+'.  
  
-- No. of New records in '+@TableName1+ ' are '+Convert(varchar(20), @Int4-@Int2)+'.  
-- No. of New records in '+@TableName2+ ' are '+Convert(varchar(20), @Int4-@Int1)+'.  
-- No. of modified but existing records are '+Convert(varchar(20), @Int3-@Int4)+'.  
------------------------------------------------------  
  
-- Comparing the data step 1 completed at '+Convert(varchar(35), GetDate(),109)  
IF @ListDiff = 0  
BEGIN  
 DROP TABLE #Table_Index  
 DROP TABLE  #ROWCount_Table   
 DROP TABLE  #TableColumns  
 RETURN  
END  
------------------------------------------------------------------------------------------  
--   Now the Tables are not identitical. Now List all the Rows that are different   --   
------------------------------------------------------------------------------------------  
IF @SvrName1=@@SERVERNAME SET @SvrName1='' ELSE SET @SvrName1='['+@SvrName1+'].'  
IF @SvrName2=@@SERVERNAME SET @SvrName2='' ELSE SET @SvrName2='['+@SvrName2+'].'  
  
IF @SvrName1='' AND @DBName1=DB_NAME() SET @DBName1='' ELSE SET @DBName1='['+@DBName1+'].'  
IF @SvrName2='' AND @DBName2=DB_NAME() SET @DBName2='' ELSE SET @DBName2='['+@DBName2+'].'  
  
IF @SvrName1='' AND @DBName1='' and @Schema1=CURRENT_USER SET @Schema1='' ELSE SET @Schema1='['+@Schema1+'].'     
IF @SvrName2='' AND @DBName2='' and @Schema2=CURRENT_USER SET @Schema2='' ELSE SET @Schema2='['+@Schema2+'].'     
   
IF (@CheckTimeStamp=1 or @Fields<>'')  
BEGIN
SELECT @SQL1='  
Select Min(A) TABLE_NAME, '+ @FieldList+' FROM   
', @SQL2= ' (Select '''+@TableName1+''' A, '+ @FieldList+ ' FROM '+@SvrName1+@DBName1+@Schema1+'['+@Table1+'] T   
  UNION ALL  
', @SQL3= '  Select '''+@TableNAme2+''', '+ @FieldList+' FROM '+@SvrName2+@DBName2+@Schema2+'['+@Table2+'] T   
  ) T   
'
END
ELSE  
SELECT @SQL1='   
 Select Min(A) TABLE_NAME, '+ @FieldList+' FROM   
', @SQL2='  (Select '''+@TableName1+''' A, T.* FROM '+@SvrName1+@DBName1+@Schema1+'['+@Table1+'] T   
  UNION ALL  
  Select '''+@TableName2+''' Table_Name, T.* FROM '+@SvrName2+@DBName2+@Schema2+'['+@Table2+'] T   
  ) T   
'  
SET @SQL4=' Group By '+ @FieldList + ' Having Count(*)<2   
Order By '
IF @Verbose=1
  PRINT @SQL1+@SQL2+@SQL3+@SQL4+@OrderBy
IF LEN(@SQL1+@SQL2+@SQL3+@SQL4+@OrderBy)<=4000
  BEGIN 
  SET @SQLStr = @SQL1+@SQL2+@SQL3+@SQL4+@OrderBy
  EXECUTE sp_ExecuteSQL @SQLStr  
  END  
ELSE  
  EXECUTE (@SQL1+@SQL2+@SQL3+@SQL4+@OrderBy)

DROP TABLE #Table_Index  
  
DROP TABLE  #ROWCount_Table   
DROP TABLE  #TableColumns  
PRINT '-- Comparing the data step 2 completed at '+Convert(varchar(35), GetDate(),109)  
  




GO
