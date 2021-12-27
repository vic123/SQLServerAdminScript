IF OBJECT_ID('usp_failed_jobs_report') IS NOT NULL  
  DROP procedure usp_failed_jobs_report 
go
CREATE  procedure usp_failed_jobs_report 
					@HoursPast int,
					@EmailList varchar(1000),
					@RunStatus int = 0  --(0==failed, use NULL for all)
--CREATE  procedure usp_failed_jobs_report 
--http://www.sqlservercentral.com/forums/shwmessage.aspx?forumid=5&messageid=125125
-- there was a good stored proc on this site awhile ago, don't remember the author:
as

-- Written by: Greg Larsen
-- Company: Department of Health, Washington State
-- Date: January 3, 2002
-- Description:  This SQL Code reports job/step failures based on a data and time range.  The
--               report built is emailed to the DBA distribution list.
--
-- Modified 04/12/2002 - Greg Larsen - Modified to support Long running jobs that cross reporting 
--                                     periods
--  This SQL Code reports job/step failures based on a data and time range.  The
--               report built is emailed to the DBA .
--  Modified 13 sep 2006 - Victor Blokhin -
--	added 	@HoursPast int (should be +, it gets * -1)
--		@EmailList varchar(1000),
--		@RunStatus int = 0  (0==failed, use NULL for all)
--	##temp_text -> #temp_text
--	master.dbo.xp_sendmail -> SendMail, message is limited to nvarchar(4000)


declare @RPT_BEGIN_DATE datetime
--declare @NUMBER_OF_DAYS int
SET NOCOUNT ON
-- Set the number of days to go back to calculate the report begin date

--	set @NUMBER_OF_DAYS = -1
	
	-- If the current date is Monday, then have the report start on Friday.
	-----------------------------------------------
	--if datepart(dw,getdate()) = 2
	
	--  set @NUMBER_OF_DAYS = -3
	-----------------------------------------------
	-- Get the report begin date and time
	
--	set @RPT_BEGIN_DATE = dateadd(day,@NUMBER_OF_DAYS,getdate()) 
	set @RPT_BEGIN_DATE = dateadd(hh, @HoursPast * -1, getdate()) 
print @RPT_BEGIN_DATE
	-- Get todays date in YYMMDD format
	-- Create temporary table to hold report
	create table #temp_text (
		id int IDENTITY, 
		email_text varchar(200), 
		WarnLevel int)
	-- Generate report heading and column headers
	insert into #temp_text (email_text) values('The following jobs/steps failed since ' + 
	                               cast(@RPT_BEGIN_DATE as char(20)) )
	insert into #temp_text (email_text) values ('run_status job                                         step_name                         start_time          stop_time           ')
	insert into #temp_text (email_text) values ('---------- ------------------------------------------- --------------------------------- ------------------- ------------------- ')
	-- Generate report detail for failed jobs/steps
	insert into #temp_text (email_text, WarnLevel)
	  select CASE run_status
			WHEN 0 THEN 	'ERROR     '
			ELSE 		'SUCCESS   '
		END + 
		substring(j.name,1,43)+ 
	           substring('                                           ',    len(j.name),43) + substring(jh.step_name,1,33) + 
	           substring('                                 ',   len(jh.step_name),33) + 
	        -- Calculate fail datetime
	        -- Add Run Duration Seconds
		convert(char(19), dbo.IntDT2DT (run_date, run_time)) + ' ' + 
		convert(char(19), 
				(dbo.IntDT2DT (run_date, run_time) + dbo.IntDT2DT (0, run_duration))
			) ,
		CASE run_status
			WHEN 0 THEN 	2
			ELSE 		1
		END 

/*	        cast(dateadd(ss, cast(substring(cast(run_duration + 1000000 as char(7)),6,2) as int),
	        -- Add Run Duration Minutes 
	        dateadd(mi,  cast(substring(cast(run_duration + 1000000 as char(7)),4,2) as int),
	        -- Add Run Duration Hours
	        dateadd(hh,  cast(substring(cast(run_duration + 1000000 as char(7)),2,2) as int),
	        -- Add Start Time Seconds
	        dateadd(ss,  cast(substring(cast(run_time + 1000000 as char(7)),6,2) as int),
	        -- Add Start Time Minutes 
	        dateadd(mi,  cast(substring(cast(run_time + 1000000 as char(7)),4,2) as int),
	        -- Add Start Time Hours
	        dateadd(hh,  cast(substring(cast(run_time + 1000000 as char(7)),2,2) as int),
	        convert(datetime,cast (run_date as char(8))))
	           ))))) as char(19)) 

+ ' SQLS	ERVER_name' */
	   from msdb.dbo.sysjobhistory jh join msdb.dbo.sysjobs j on jh.job_id=j.job_id
	   where   getdate() >
	               -- Calculate fail datetime
	               -- Add Run Duration Seconds
			(dbo.IntDT2DT (run_date, run_time) + dbo.IntDT2DT (0, run_duration))
/*select convert (datetime, 1000000)
	               dateadd(ss,
	               cast(substring(cast(run_duration + 1000000 as char(7)),6,2) as int),
	               -- Add Run Duration Minutes 
	               dateadd(mi,
	               cast(substring(cast(run_duration + 1000000 as char(7)),4,2) as int),
	               -- Add Run Duration Hours
	               dateadd(hh,
	               cast(substring(cast(run_duration + 1000000 as char(7)),2,2) as int),
	               -- Add Start Time Seconds
	               dateadd(ss,
	               cast(substring(cast(run_time + 1000000 as char(7)),6,2) as int),
	               -- Add Start Time Minutes 
	               dateadd(mi,
	               cast(substring(cast(run_time + 1000000 as char(7)),4,2) as int),
	               -- Add Start Time Hours
	               dateadd(hh,
	               cast(substring(cast(run_time + 1000000 as char(7)),2,2) as int),
	               convert(datetime,cast (run_date as char(8))))
	               ))))))  
*/
			
	and  @RPT_BEGIN_DATE < 
			--tryout: select getdate() + convert(datetime, '23:04:30.030') 
			(dbo.IntDT2DT (run_date, run_time) + dbo.IntDT2DT (0, run_duration)) 
      and jh.run_status = isNull(@RunStatus, jh.run_status) 
-- Calculate fail datetime
	               -- Add Run Duration Seconds
/*
	               dateadd(ss,
	               cast(substring(cast(run_duration + 1000000 as char(7)),6,2) as int),
	               -- Add Run Duration Minutes 
	               dateadd(mi,
	               cast(substring(cast(run_duration + 1000000 as char(7)),4,2) as int),
	               -- Add Run Duration Hours
	               dateadd(hh,
	               cast(substring(cast(run_duration + 1000000 as char(7)),2,2) as int),
	               -- Add Start Time Seconds
	               dateadd(ss,
	               cast(substring(cast(run_time + 1000000 as char(7)),6,2) as int),
	               -- Add Start Time Minutes 
	               dateadd(mi,
	               cast(substring(cast(run_time + 1000000 as char(7)),4,2) as int),
	               -- Add Start Time Hours
	               dateadd(hh,
	               cast(substring(cast(run_time + 1000000 as char(7)),2,2) as int),
	               convert(datetime,cast (run_date as char(8))))
	               )))))) 
*/

		DECLARE @message nvarchar(4000)
		DECLARE @subject nvarchar(100)
		SELECT @subject = @@SERVERNAME + '.SQLAdmin.JobHistoryScan - ' 
			+ isNull('ERROR(' + 
					convert(varchar(10), 
						nullIf(
							sum((WarnLevel & 2) / 2),
							0)
					) 
				+ ')', 
			'')
			+ isNull('SUCCESS(' + 
					convert(varchar(10), 
						nullIf(
							sum((WarnLevel & 1) / 1),
							0)
					) 
				+ ')', 
			'')
		FROM #temp_text 

		SELECT @message = isNull(@message + CHAR(10), '') + email_text 	
			FROM #temp_text WHERE WarnLevel IS NOT NULL
		IF @message IS NOT NULL BEGIN
			SELECT @message = email_text + CHAR(10) + @message 
				FROM #temp_text WHERE id < 4 ORDER BY id DESC
			EXEC SendMail 	@To = @EmailList,
					@Subject = @subject,
					@Message = @message
		END

/*	
	exec master.dbo.xp_sendmail @recipients='DBAname',
	
	              @subject='Check for Failed Jobs - Contains jobs/steps that have failed.', 
	
	              @query='select * from #temp_text' , @no_header='true', @width=150

*/	
	-- Drop temporary table
	SET NOCOUNT OFF
	drop table #temp_text

GO

/*
test:
null message
@RunStatus = NULL

SELECT 6*24
EXEC usp_failed_jobs_report @HoursPast = 156,
			@EmailList = 'victor@infoplanet-usa.com,vic@infoplanet-usa.com',
			@RunStatus = NULL

EXEC usp_failed_jobs_report @HoursPast = 168,
			@EmailList = 'victor@infoplanet-usa.com,vic@infoplanet-usa.com',
			@RunStatus = 0


EXEC usp_failed_jobs_report @HoursPast = 156,
			@EmailList = 'victor@infoplanet-usa.com,vic@infoplanet-usa.com',
			@RunStatus = NULL

EXEC usp_failed_jobs_report @HoursPast = 156,
			@EmailList = 'victor@infoplanet-usa.com,vic@infoplanet-usa.com',
			@RunStatus = 1
*/
