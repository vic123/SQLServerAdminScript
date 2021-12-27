
IF EXISTS (SELECT * FROM dbo.sysobjects 
		WHERE id = object_id(N'[dbo].[StringListToTable]') 
		AND objectproperty(id, N'IsTableFunction') = 1)
DROP FUNCTION [dbo].[StringListToTable]
GO

CREATE FUNCTION StringListToTable (
						@list      ntext,
						@delimiter nvarchar(10) = N','
				)
	RETURNS @tbl TABLE (	listpos int IDENTITY(1, 1) NOT NULL,
				str     varchar(4000),
				nstr    nvarchar(2000)) 
/****************************************************************************************************************
* ORIGIN: iter_charlist_to_table form http://www.sommarskog.se
* Modified into a function with string instead of char(1) delimiter  */
/**************
MODIFICATIONS:
060825	Changed not to return 1 row with '' str for empty list. returns no records now.
***************/
/**************
test:
SELECT * FROM StringListToTable ('sdf', ',')
SELECT * FROM StringListToTable ('', ',')

***************/
AS BEGIN
		DECLARE 	@pos      int,
				@textpos  int,
				@chunklen smallint,
				@tmpstr   nvarchar(4000),
				@leftover nvarchar(4000),
				@tmpval   nvarchar(4000)

		SET @textpos = 1
		SET @leftover = ''
		WHILE @textpos <= datalength(@list) / 2
		BEGIN
			SET @chunklen = 4000 - datalength(@leftover) / 2
			SET @tmpstr = @leftover + substring(@list, @textpos, @chunklen)
			SET @textpos = @textpos + @chunklen
			
			SET @pos = charindex(@delimiter, @tmpstr)
			
			WHILE @pos > 0
			BEGIN
				SET @tmpval = ltrim(rtrim(left(@tmpstr, charindex(@delimiter, @tmpstr) - 1)))
				INSERT @tbl (str, nstr) VALUES(@tmpval, @tmpval)
				SET @tmpstr = substring(@tmpstr, @pos + len(@delimiter), len(@tmpstr))
				SET @pos = charindex(@delimiter, @tmpstr)
			END
				
			SET @leftover = @tmpstr
		END
		IF len (isNull(ltrim(rtrim(@leftover)), '')) <> 0 BEGIN
			INSERT @tbl(str, nstr) VALUES (ltrim(rtrim(@leftover)), ltrim(rtrim(@leftover)))
		END
		RETURN
	END
go

