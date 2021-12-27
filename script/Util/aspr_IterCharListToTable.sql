IF OBJECT_ID('aspr_IterCharListToTable') IS NOT NULL  
  DROP FUNCTION aspr_IterCharListToTable

go
		
CREATE FUNCTION aspr_IterCharListToTable (
						@list      ntext,
--(051122)						@delimiter nchar(1) = N','
						@delimiter nvarchar(10) = N','
				)
	RETURNS @tbl TABLE (listpos int IDENTITY(1, 1) NOT NULL,
							str     varchar(4000),
							nstr    nvarchar(2000)) AS
	BEGIN
		DECLARE @pos      int,
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
--(051122)				SET @tmpstr = substring(@tmpstr, @pos + 1, len(@tmpstr))
				SET @tmpstr = substring(@tmpstr, @pos + len(@delimiter), len(@tmpstr))
				SET @pos = charindex(@delimiter, @tmpstr)
			END
				
			SET @leftover = @tmpstr
		END
			
		INSERT @tbl(str, nstr) VALUES (ltrim(rtrim(@leftover)), ltrim(rtrim(@leftover)))
		RETURN
	END
go

