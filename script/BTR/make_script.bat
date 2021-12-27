TYPE nul > btr_script.sql 
REM CHECK THAT ALL FILES ARE PRESENT
if not exist blocking_schema.sql goto :error	
if not exist usp_blocking_tmp2base.sql goto :error	
if not exist usp_blocking_kill.sql goto :error	
if not exist usp_blocking_trace.sql goto :error	
if not exist usp_blocking_trace_sjh.sql goto :error	
if not exist usp_blocking_audit.sql goto :error	
if not exist usp_blocking_report.sql goto :error	
if not exist btrp_RptGAP.sql goto :error	
if not exist btr_view.sql goto :error	


TYPE blocking_schema.sql >> btr_script.sql
TYPE usp_blocking_tmp2base.sql >> btr_script.sql
TYPE usp_blocking_kill.sql >> btr_script.sql
TYPE usp_blocking_trace.sql >> btr_script.sql
TYPE usp_blocking_trace_sjh.sql >> btr_script.sql
TYPE usp_blocking_audit.sql >> btr_script.sql
TYPE usp_blocking_report.sql >> btr_script.sql
TYPE btrp_RptGAP.sql >> btr_script.sql
TYPE btr_view.sql >> btr_script.sql

goto ok
:error
ECHO Required file does not exist
:ok