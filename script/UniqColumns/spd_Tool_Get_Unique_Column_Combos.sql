
CREATE PROCEDURE [dbo].[spd_Tool_Get_Unique_Column_Combos]
@Table_Name varchar(250), -- req'd; the name of the table on which to run report
@Exclude_Columns_List varchar(1000) = '', -- opt'l; list of columns to exclude from checking
@Max_Combo_Size tinyint = 10, -- opt'l; the maximum recursive search depth
@Curr_Combo_Size tinyint = 0, -- (USER DOES NOT SPECIFY) max # columns in current
-- column combo strain ( >= 1 and <= #columns)
@Start_With tinyint = 1, -- (USER DOES NOT SPECIFY) the value item number to start at
@Already_Picked varchar(1000) = '' -- (USER DOES NOT SPECIFY) any values that must be included
-- in the current "strain" of column combos

/***************************************************************************************************
Written by: Jesse McLain
Purpose: To return all combinations of size n of values in a table's column
Input Parameters: see below
Output Parameters: none
Called By: user
***************************************************************************************************
Update History
Date Author Purpose
11/29/2007 Jesse McLain Created spd
11/30/2007 Jesse McLain Chgd approach from depth-first to breadth-first
12/03/2007 Jesse McLain Added use of @uniq_fnd, to short-circuit further searching once
a unique combo w/in a strain is found
12/05/2007 Jesse McLain Expanded use of @uniq_fnd so that the spd returns it, and in the
loop that recursively calls itself, added a short circuit in the
WHILE clause to stop searching if success found in deeper strain.
Added use of fn_Wrap_Items_In_List to automatically wrap column
names in @Exclude_Columns_List in quotes for SQL statement.
***************************************************************************************************
ToDo List
Date Added By Business Need
12/03/2007 Jesse McLain Add start-at/stop-at parameters, so that user can exclude searching
columns based on range of column numbers
***************************************************************************************************
Notes
11/30/07 10:51:50 AM - this version is the most brute force method possible. It works, but it is
terribly inefficient. It is also the most simple implementation possible. Because of its depth-first
searching, it over-reports uniqueness. For example, let's say we're checking columns A, B, and C. If
A is not unique, then it checks all strains beginning with A. But let's say that column B is unique.
Then combo AB is unique, and it is redundant to check both AB and B for uniqueness, but the depth-first
method will do exactly that.
In order to improve this, I need to change this to a breadth-first approach. To do that, keep the
existing "Col_Names_Cursor" cursor. Instead of putting the recursive calls inside of it, have it
check the uniqueness of the current strains, report them if they are, and insert the non-unique
combos to check later into a local temp table. Open a second cursor on that temp table after
"Col_Names_Cursor" finishes, which will then make recursive calls on those non-unique combos. I think
that this new breadth-first approach will be ideal.

11/30/07 11:35:37 AM - I don't think that using the sample table with the new breadth-first approach
will provide any benefit. The reason being, whether the combo in the sample table is unique or not, we
still have to check the combo in the full table. Pseudocode of breadth-first with sample table usage:

LOOP thru cursor of current strain
IF combo in sample table is unique
IF combo in whole table is unique
INSERT into results table (reporting as unique)
ELSE
INSERT into temp table
ELSE
INSERT into temp table
ENDLOOP

11/30/07 11:48:48 AM - the pseudocode above shows that the sample table will be useful, as it allows
us to short-circuit checking the whole table for non-uniqueness if the sample is not unique. Finishing
out the pseudocode for the second loop:

LOOP thru cursor of temp table
CALL spd recursively on new strain
ENDLOOP

***************************************************************************************************/

AS

SET NOCOUNT ON

IF @Table_Name = 'help'
BEGIN
PRINT 'PROCEDURE [dbo].[spd_Tool_Get_Unique_Column_Combos] '
PRINT ' @Table_Name varchar(250), -- REQUIRED; the name of the table on which to run report'
PRINT ' @Exclude_Columns_List varchar(1000) = '''', -- OPTIONAL; list of columns to exclude from checking'
PRINT ' @Max_Combo_Size tinyint = 10 -- OPTIONAL; the max #columns to check within a combo'
RETURN
END

DECLARE @Find_First_Only tinyint -- set to 1 if you want to stop searching for more results if you found one
SET @Find_First_Only = 1


-- if this is the initial call to this spd by user, then do some temp table creation:
IF @Curr_Combo_Size = 0
BEGIN
-- create a sample table from the source table to expedite uniqueness checking:
DECLARE @Sample_Size smallint
SET @Sample_Size = 1000

DECLARE @Sample_Table varchar(100)
SET @Sample_Table = '##Sample_Table'
IF EXISTS(SELECT 1 FROM TempDb.dbo.SysObjects WHERE NAME = '##Sample_Table') DROP TABLE ##Sample_Table

DECLARE @sql varchar(8000)
SET @sql = 'SELECT TOP ' + LTRIM(STR(@Sample_Size)) + ' * INTO ' + @sample_table + ' FROM ' + @Table_Name
EXEC(@sql)



-- create a temp table ##ColumnsAvailable to hold the columns to check:
IF EXISTS(SELECT 1 FROM TempDb.dbo.SysObjects WHERE NAME = '##ColumnsAvailable') DROP TABLE ##ColumnsAvailable
CREATE TABLE ##ColumnsAvailable (ColName varchar(200), ColNum smallint IDENTITY(1,1))

DECLARE @Exclude_Columns_List_Clause varchar(max)
SET @Exclude_Columns_List_Clause = CASE WHEN @Exclude_Columns_List IS NOT NULL AND @Exclude_Columns_List <> ''
THEN ' AND C.Name NOT IN (' + dbo.fn_Wrap_Items_In_List(@Exclude_Columns_List, ',', '''') + ')' ELSE '' END

SET @sql = 'INSERT INTO ##ColumnsAvailable (ColName)
SELECT C.Name
FROM SysColumns C
JOIN SysObjects O ON O.Id = C.Id
WHERE O.Name = ''' + @Table_Name + '''' + @Exclude_Columns_List_Clause

EXEC(@sql)


IF EXISTS(SELECT * FROM TempDb.dbo.SysObjects WHERE NAME = '##Uniq_Col_Combo_Results') DROP TABLE ##Uniq_Col_Combo_Results
CREATE TABLE ##Uniq_Col_Combo_Results (Combo_Txt varchar(1000), Pick_Size tinyint)
END


-- SQL server 2005 can only have 32 nested spd calls, so we have to limit the @Max_Combo_Size:
SET @Max_Combo_Size = CASE WHEN @Max_Combo_Size > 30 THEN 30 ELSE @Max_Combo_Size END


DECLARE @Curr_ColName varchar(200) -- holds values for cursor Col_Names_Cursor
DECLARE @Curr_ColNum tinyint -- holds values for cursor Col_Names_Cursor
DECLARE @Curr_Combo_ToChk varchar(1000)
DECLARE @Curr_Combo_Size_Plus1 tinyint
SET @Curr_Combo_Size_Plus1 = @Curr_Combo_Size + 1
DECLARE @uniq_fnd tinyint
SET @uniq_fnd = 0

DECLARE @Curr_ColNum_Plus1 tinyint


-- this is a temp table that holds strains to test in recursive calls:
CREATE TABLE #Non_Uniqs (Combo_Txt varchar(1000), Col_Num tinyint)


DECLARE Col_Names_Cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT ColName, ColNum
FROM ##ColumnsAvailable
WHERE ColNum >= @Start_With
ORDER BY ColNum

OPEN Col_Names_Cursor

-- main loop
FETCH NEXT FROM Col_Names_Cursor INTO @Curr_ColName, @Curr_ColNum
WHILE @@FETCH_STATUS = 0 AND @uniq_fnd = 0
BEGIN
SET @Curr_ColNum_Plus1 = @Curr_ColNum + 1
SET @Curr_Combo_ToChk = CASE WHEN @Already_Picked = '' THEN '' ELSE @Already_Picked + ',' END + @Curr_ColName
SET @uniq_fnd = 0


-- first we're going to check the sample table for uniqueness of the current combo
IF EXISTS(SELECT 1 FROM TempDb.dbo.SysObjects WHERE NAME = '##Dupes') DROP TABLE ##Dupes
SET @sql = 'SELECT ' + @Curr_Combo_ToChk + ', cnt_dupes=COUNT(*) INTO ##Dupes FROM ##Sample_Table GROUP BY '
+ @Curr_Combo_ToChk + ' HAVING COUNT(*) > 1'
EXEC(@sql)

IF NOT EXISTS(SELECT TOP 1 1 FROM ##Dupes) -- true if combo is unique in sample table
BEGIN
-- if the combo is unique in the sample table, then we check it in the whole table:

DROP TABLE ##Dupes
SET @sql = 'SELECT ' + @Curr_Combo_ToChk + ', cnt_dupes=COUNT(*) INTO ##Dupes FROM ' + @Table_Name
+ ' GROUP BY ' + @Curr_Combo_ToChk + ' HAVING COUNT(*) > 1'
EXEC(@sql)

IF NOT EXISTS(SELECT TOP 1 1 FROM ##Dupes) -- true if combo is unique in whole table
BEGIN
-- if it's unique here, then we're done with this strain:
--PRINT 'COMBINATION "' + @Curr_Combo_ToChk + '" IS UNIQUE.'
INSERT INTO ##Uniq_Col_Combo_Results (Combo_Txt) VALUES (@Curr_Combo_ToChk)
SET @uniq_fnd = 1
END
ELSE -- combo is not unique in whole table
BEGIN
--PRINT 'Combination "' + @Curr_Combo_ToChk + '" is not unique.'
INSERT INTO #Non_Uniqs (Combo_Txt, Col_Num) VALUES (@Curr_Combo_ToChk, @Curr_ColNum_Plus1)
END
END
ELSE -- combo is not unique in sample table
BEGIN
--PRINT 'Combination "' + @Curr_Combo_ToChk + '" is not unique.'
INSERT INTO #Non_Uniqs (Combo_Txt, Col_Num) VALUES (@Curr_Combo_ToChk, @Curr_ColNum_Plus1)
END


FETCH NEXT FROM Col_Names_Cursor INTO @Curr_ColName, @Curr_ColNum
END

CLOSE Col_Names_Cursor
DEALLOCATE Col_Names_Cursor



/* now we have a temp table, #Non_Uniqs, holding the combos from the querying above that
are non-unique in the table of interest. We want to determine the uniqueness of their
derivatives (which are combos that have them as a beginning) */

IF @Curr_Combo_Size < @Max_Combo_Size - 1 -- make sure we're not at search depth limit
AND @uniq_fnd = 0 -- short-circuit further searching by success
BEGIN
DECLARE Non_Uniqs_Cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT Combo_Txt, Col_Num
FROM #Non_Uniqs
OPEN Non_Uniqs_Cursor

FETCH NEXT FROM Non_Uniqs_Cursor INTO @Curr_Combo_ToChk, @Curr_ColNum_Plus1

WHILE @@FETCH_STATUS = 0 AND @uniq_fnd = 0
BEGIN
EXEC @uniq_fnd = spd_Tool_Get_Unique_Column_Combos
@Table_Name,
@Exclude_Columns_List,
@Max_Combo_Size,
@Curr_Combo_Size_Plus1,
@Curr_ColNum_Plus1,
@Curr_Combo_ToChk

FETCH NEXT FROM Non_Uniqs_Cursor INTO @Curr_Combo_ToChk, @Curr_ColNum_Plus1
END

CLOSE Non_Uniqs_Cursor
DEALLOCATE Non_Uniqs_Cursor
END



-- if this is the initial call to this spd by user, then do some clean up and report results:
IF @Curr_Combo_Size = 0
BEGIN

IF EXISTS(SELECT TOP 1 1 FROM ##Uniq_Col_Combo_Results)
BEGIN
IF (SELECT COUNT(*) FROM ##Uniq_Col_Combo_Results) > 1
PRINT 'Here are the combinations of columns found to be unique in "' + @Table_Name + '":'
ELSE IF @Find_First_Only = 1
PRINT 'Here is the first combination of columns found to be unique in "' + @Table_Name + '":'
ELSE
PRINT 'Here is the only combination of columns found to be unique in "' + @Table_Name + '":'

DECLARE Uniqs_Cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT Combo_Txt FROM ##Uniq_Col_Combo_Results
OPEN Uniqs_Cursor

FETCH NEXT FROM Uniqs_Cursor INTO @Curr_Combo_ToChk

WHILE @@FETCH_STATUS = 0
BEGIN
PRINT RTRIM(@Curr_Combo_ToChk)
FETCH NEXT FROM Uniqs_Cursor INTO @Curr_Combo_ToChk
END

CLOSE Uniqs_Cursor
DEALLOCATE Uniqs_Cursor
END
ELSE
BEGIN
PRINT 'No combinations of columns were found to be unique in "' + @Table_Name + '"'
END


DROP TABLE ##ColumnsAvailable
DROP TABLE ##Sample_Table
DROP TABLE ##Uniq_Col_Combo_Results
END
ELSE
RETURN @uniq_fnd







