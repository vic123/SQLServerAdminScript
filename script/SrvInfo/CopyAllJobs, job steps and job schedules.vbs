
' http://www.sqlservercentral.com/scripts/contributions/758.asp
' Script Rating       Total number of votes [6] 
' By: rhandloff 
' This vbscript will generate the sql to recreate all the jobs running on a given SQL server. I wrote this because the last time we migrated a SQL server, I ended up re-creating all the jobs, steps and schedules by hand using the Enterprise Manager. It was the slowest, dullest and most error-prone part of the migration. Being a lazy programmer (aren't all good programmers lazy?) and being in love with scripting languages (especially Perl and VBScript) I thought I would throw a quick little script together to do the job.
' 
' So, set up a udl and capture the output to a text file. Paste the sql statements into the query analyzer and voila!
' 
' You could easily use a connection object to execute the sql as it ran, or save it to a file and then call osql through a command shell, but I chose not to do that since our migration will be stressful enough without worrying that something went wrong with the script. I'd rather see the SQL and paste it into the query analyzer prior to executing the SQL. 


Option Explicit

Dim cn
Dim rsJobs, rsJobSteps, rsJobSchedule
Dim sSQL  
Dim sAppPath
Const adOpenForwardOnly = 0
Const adLockReadOnly = 1


WScript.Echo "Beginning Now : " & Now


sAppPath = getScriptPath()
sSQL = "exec sp_help_job"





'-- Connect to Database
Set cn = CreateObject("ADODB.Connection")
cn.Open "File Name=" & sAppPath & "CopyAllJobs.UDL"


'-- Open Table
Set rsJobs = CreateObject("ADODB.Recordset")
Set rsJobSteps = CreateObject("ADODB.Recordset")
Set rsJobSchedule = CreateObject("ADODB.Recordset")
rsJobs.Open sSQL, cn , adOpenForwardOnly, adLockReadOnly
	
Do While Not rsJobs.EOF
	WScript.echo "/***" & rsJobs("name") & "***/"
	wscript.echo "exec sp_add_job @job_name = '" & ScrubString(rsJobs("name")) & "', @enabled = '" & rsJobs("enabled") & "', @description = '" & ScrubString(rsJobs("description")) & "', @start_step_id = '" & rsJobs("start_step_id") & "', @owner_login_name = '" & rsJobs("owner") & "', @notify_level_eventlog = '" & rsJobs("notify_level_eventlog") & "', @delete_level = '" & rsJobs("delete_level") & "'"
	WScript.Echo vbtab & "/***Steps***/"
	sSQL = "exec sp_help_jobstep @job_id = '" & rsJobs("job_id") & "'"
	rsJobSteps.Open sSQL, cn , adOpenForwardOnly, adLockReadOnly
	Do While Not rsJobSteps.EOF
		Wscript.echo "exec sp_add_jobstep @job_name = '" & ScrubString(rsJobs("name")) & "', @step_id = '" & rsJobSteps("step_id") & "', @step_name = '" & ScrubString(rsJobSteps("step_name")) & "', @subsystem = '" & rsJobSteps("subsystem") & "', @command = '" & ScrubString(rsJobSteps("command")) & "', @flags = '" & rsJobSteps("flags") & "', @cmdexec_success_code = '" & rsJobSteps("cmdexec_success_code") & "', @on_success_action = '" & rsJobSteps("on_success_action") & "', @on_success_step_id = '" & rsJobSteps("on_success_step_id") & "', @on_fail_action = '" & rsJobSteps("on_fail_action") & "', @on_fail_step_id = '" & rsJobSteps("on_fail_step_id") & "', @database_name = '" & rsJobSteps("database_name") & "', @database_user_name = '" & rsJobSteps("database_user_name") & "', @retry_attempts = '" & rsJobSteps("retry_attempts") & "', @retry_interval = '" & rsJobSteps("retry_interval") & "', @output_file_name = '" & rsJobSteps("output_file_name") & "'"
		rsJobSteps.MoveNext
	Loop
	rsJobSteps.Close
	WScript.Echo vbtab & "/***Schedule***/"
	sSQL = "exec sp_help_jobschedule  @job_id = '" & rsJobs("job_id") & "'"
	rsJobSchedule.Open sSQL, cn , adOpenForwardOnly, adLockReadOnly
	Do While Not rsJobSChedule.EOF
		WScript.Echo "exec sp_add_jobschedule @job_name = '" & ScrubString(rsJobs("name")) & "', @name = '" & ScrubString(rsJobSchedule("schedule_name")) & "', @enabled = '" & rsJobSchedule("enabled") & "', @freq_type = '" & rsJobSchedule("freq_type") & "', @freq_interval = '" & rsJobSchedule("freq_interval") & "', @freq_subday_type = '" & rsJobSchedule("freq_subday_type") & "', @freq_subday_interval = '" & rsJobSchedule("freq_subday_interval") & "', @freq_relative_interval = '" & rsJobSchedule("freq_relative_interval") & "', @freq_recurrence_factor = '" & rsJobSchedule("freq_recurrence_factor") & "', @active_start_time = '" & rsJobSchedule("active_start_time") & "'"
		rsJobSchedule.MoveNext
	Loop
	rsJobSchedule.Close
	
	
	rsJobs.MoveNext
Loop
	
rsJobs.Close
cn.Close

Set rsJobs = nothing
Set rsJobSteps = nothing
Set rsJobSchedule= Nothing
Set cn = nothing



Wscript.Echo sData



WScript.Echo "Ending Now : " & Now

function ScrubString (sInStr)
	ScrubString = replace (sInStr,"'","''")
End Function

public function getScriptPath()
dim s
   s = WScript.ScriptFullName
   s = left(s, InStrRev(s, "\" , -1))
   getScriptPath = s
end function

