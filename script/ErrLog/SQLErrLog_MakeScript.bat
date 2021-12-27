TYPE nul > _SQLErrLog_script.tmp.sql 
REM CHECK THAT ALL FILES ARE PRESENT

REM TYPE sp_EmailAlert2.sql >> _SQLErrLog_script.tmp.sql
TYPE SQL_ERR_LOG_Schema.sql >> _SQLErrLog_script.tmp.sql
TYPE ADM_GET_SYS_MESSAGE.sql >> _SQLErrLog_script.tmp.sql
TYPE ADM_WRITE_SQL_ERR_LOG.sql >> _SQLErrLog_script.tmp.sql
TYPE ADM_RPT_SQL_ERR_LOG.sql >> _SQLErrLog_script.tmp.sql
TYPE ADM_MAIL_CURSPROC_SQL_ERR_LOG.sql >> _SQLErrLog_script.tmp.sql
