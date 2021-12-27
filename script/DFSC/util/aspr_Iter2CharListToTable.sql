
DROP FUNCTION aspr_Iter2CharListToTable
go

--(051123) CREATE FUNCTION iter_charlist_to_table (		
CREATE FUNCTION aspr_Iter2CharListToTable (
						@list      ntext,
--(051122)						@delimiter nchar(1) = N','
						@delimiter nvarchar(10) = N','
				)
	RETURNS @tbl TABLE (listpos int IDENTITY(1, 1) NOT NULL,
							str1     varchar(2000),
							str2     varchar(2000),
							nstr1    nvarchar(1000),
							nstr2    nvarchar(1000)) AS
	BEGIN
		DECLARE @pos      int,
				@textpos  int,
				@chunklen smallint,
				@tmpstr   nvarchar(4000),
				@leftover nvarchar(4000),
--(051123) 				@tmpval   nvarchar(4000)
				@tmpval nvarchar(4000), @tmpval2   nvarchar(4000),
				@do2nd_pos			bit
		
		IF (@list IS NULL) RETURN
		
		SET @textpos = 1
		SET @leftover = ''
		SET @do2nd_pos = 0
		WHILE @textpos <= datalength(@list) / 2
		BEGIN
			SET @chunklen = 4000 - datalength(@leftover) / 2
			SET @tmpstr = @leftover + substring(@list, @textpos, @chunklen)
			SET @textpos = @textpos + @chunklen
			
			SET @pos = charindex(@delimiter, @tmpstr)
			
			WHILE @pos > 0
			BEGIN
				IF (@do2nd_pos = 0) BEGIN
					SET @tmpval = ltrim(rtrim(left(@tmpstr, charindex(@delimiter, @tmpstr) - 1)))
	--(051123)				INSERT @tbl (str, nstr) VALUES(@tmpval, @tmpval)
	--(051122)				SET @tmpstr = substring(@tmpstr, @pos + 1, len(@tmpstr))
					SET @tmpstr = substring(@tmpstr, @pos + len(@delimiter), len(@tmpstr))
					SET @pos = charindex(@delimiter, @tmpstr)
				END
	--(051123-beg)
				IF (@pos <= 0) BEGIN 
					SET @do2nd_pos = 1
					BREAK
				END
				SET @tmpval2 = ltrim(rtrim(left(@tmpstr, charindex(@delimiter, @tmpstr) - 1)))
				SET @tmpstr = substring(@tmpstr, @pos + len(@delimiter), len(@tmpstr))
				SET @pos = charindex(@delimiter, @tmpstr)
				INSERT @tbl (str1, nstr1, str2, nstr2) VALUES(@tmpval, @tmpval, @tmpval2, @tmpval2)
				SET @do2nd_pos = 0
--(051123-end)
			END
			SET @leftover = @tmpstr
		END
--(051123)		INSERT @tbl(str, nstr) VALUES (ltrim(rtrim(@leftover)), ltrim(rtrim(@leftover)))
		INSERT @tbl (str1, nstr1, str2, nstr2) VALUES(@tmpval, @tmpval, ltrim(rtrim(@leftover)), ltrim(rtrim(@leftover)))
		RETURN
	END

GO

/*
SELECT * FROM iter_2charlist_to_table('C::200::F::20%', '::')
SELECT * FROM iter_2charlist_to_table('g:\tmp\::7D::k:\temp::14D', '::')
SELECT * FROM iter_2charlist_to_table(NULL, '::') 
SELECT * FROM iter_charlist_to_table('::', '::') 
SELECT * FROM iter_charlist_to_table('', '::') 
*/

