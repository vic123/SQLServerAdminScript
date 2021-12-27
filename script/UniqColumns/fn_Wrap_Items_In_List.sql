IF OBJECT_ID('fn_Wrap_Items_In_List') IS NOT NULL  
  DROP FUNCTION [dbo].[fn_Wrap_Items_In_List]
GO
CREATE FUNCTION [dbo].[fn_Wrap_Items_In_List]
(@Original_List varchar(1000), -- the original list to crack open
@List_Delimiters varchar(100) = ',', -- the string serving as item delimiters
@Item_Marker varchar(100) = '') -- string to wrap the items in before putting back together
RETURNS varchar(max)
/***************************************************************************************************
Written by: Jesse McLain
Purpose: Given a delimited string, this function will crack it open, parse out the items
in the list, wrap the items in strings passed into @Item_Marker param, and then
concatenate the new items back into list
Input Parameters: see below
Output Parameters: returns varchar(max)
Called By: user
***************************************************************************************************
Update History
Date Author Purpose
12/05/2007 Jesse McLain Created function
***************************************************************************************************
ToDo List
Date Added By Business Need
***************************************************************************************************
Notes
***************************************************************************************************/
AS
BEGIN

DECLARE @NewList varchar(max)
SET @NewList = ''
DECLARE @ListItem varchar(200)


DECLARE List_Items_Cursor CURSOR FOR
SELECT Value FROM dbo.fn_Split(@Original_List, @List_Delimiters)

OPEN List_Items_Cursor

FETCH NEXT FROM List_Items_Cursor INTO @ListItem
WHILE @@FETCH_STATUS = 0
BEGIN
SET @NewList = @NewList + @Item_Marker + @ListItem + @Item_Marker + @List_Delimiters
FETCH NEXT FROM List_Items_Cursor INTO @ListItem
END

CLOSE List_Items_Cursor
DEALLOCATE List_Items_Cursor

IF @NewList <> '' SET @NewList = LEFT(@NewList, LEN(@NewList) - 1)

RETURN @NewList
END
GO