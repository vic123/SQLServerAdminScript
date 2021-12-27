if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[IntDT2DT]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[IntDT2DT]
GO
CREATE FUNCTION dbo.IntDT2DT (@date int, @time int) RETURNS datetime 
--Modified 13 sep 2006 - serious bugs in conversion fixed (errors with zero datetime parts)
AS BEGIN
/*
	DECLARE @sdate varchar(100), @stime varchar(100)
	SET @sdate = right('00000000' + convert(varchar(100), @date), 8)
	SET @stime = right('000000' + convert(varchar(100), @time), 6)
*/
	DECLARE @zero_date datetime 
	SET @zero_date = convert(datetime, 0)

	DECLARE @year int, @month int, @day int
/*	SET @year = convert(int, substring(@sdate, 1, 4))
	SET @month = convert(int, substring(@sdate, 5, 2))
	SET @day = convert(int, substring(@sdate, 7, 2))*/

	SET @year = floor(@date / 10000)
	SET @month = floor(@date / 100)
	SET @day = @date 
	IF (@month <> 0) SET @day = @date % (@month * 100)
	IF (@year <> 0) SET @month = @month % (@year * 100)


	DECLARE @hour int, @minute int, @second int
/*	SET @hour = convert(int, substring(@stime, 1, 2))
	SET @minute = convert(int, substring(@stime, 3, 2))
	SET @second = convert(int, substring(@stime, 5, 2))*/
	SET @hour = floor(@time / 10000)
	SET @minute = floor(@time / 100)
	SET @second = @time 
	IF (@minute <> 0) SET @second = @second % (@minute * 100)
	IF (@hour <> 0) SET @minute = @minute % (@hour * 100)

--% (@hour * 10000 + @minute * 100)

	DECLARE @result datetime
	SET @result = @zero_date
	IF (@year <> 0) SET @result = dateadd(yyyy, @year - datepart(yyyy, @zero_date), @result)
	IF (@month <> 0) SET @result = dateadd(mm, @month - datepart(mm, @zero_date), @result)
	IF (@day <> 0) SET @result = dateadd(dd, @day - datepart(dd, @zero_date), @result)

	SET @result = dateadd(hh, @hour - datepart(hh, @zero_date), @result)
	SET @result = dateadd(n, @minute - datepart(n, @zero_date), @result)
	SET @result = dateadd(s, @second - datepart(s, @zero_date), @result)
	RETURN @result
END
GO
--SELECT convert(datetime, 0)
--SELECT dbo.IntDT2DT(20030330, 234512)
--SELECT dbo.IntDT2DT(00000330, 000512)
--SELECT dbo.IntDT2DT(00000000, 000012)

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[DT2IntDate]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[DT2IntDate]
GO
CREATE FUNCTION dbo.DT2IntDate (@date datetime) RETURNS int
AS BEGIN
	DECLARE @year int, @month int, @day int
	SET @year = datepart(yyyy, @date)
	SET @month = datepart(mm, @date)
	SET @day = datepart(dd, @date)
	
	DECLARE @job_date int
	SET @job_date = @year * 10000 + @month * 100 + @day

	RETURN @job_date
END
GO
--SELECT dbo.DT2IntDate(getdate())

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[DT2IntTime]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[DT2IntTime]
GO
CREATE FUNCTION dbo.DT2IntTime (@date datetime) RETURNS int
AS BEGIN
	DECLARE @hour int, @minute int, @second int
	SET @hour = datepart(hh, @date)
	SET @minute = datepart(n, @date)
	SET @second = datepart(s, @date)
	
	DECLARE @job_time int
	SET @job_time = @hour * 10000 + @minute * 100 + @second
	RETURN @job_time
END
GO
--SELECT dbo.DT2IntTime(getdate())
