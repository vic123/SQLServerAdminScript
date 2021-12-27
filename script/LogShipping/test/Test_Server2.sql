USE LogShipping
GO

DELETE FROM LogShipping_Audit

--DROP DATABASE Prod
go

RESTORE DATABASE Prod WITH RECOVERY

EXEC usp_LogShipping_Continue 
	@dbname = 'Prod'
	,@backuppath = 'G:\SharedFolder\LogShipping\'
	,@standbyfile = 'G:\SharedFolder\LogShipping\pad_standby.rdo'
	,@fileprefix = 'Prod_'
	,@allbackuppostfix = '.bak'
	,@fullbackuppostfix = '_full.bak'
	,@diffbackuppostfix = '_dif.bak'
	,@logbackuppostfix = '_trn.bak'
	,@fullbackupmovecommand = '   MOVE ''Prod_Data'' TO ''K:\Program Files\Microsoft SQL Server\MSSQL$LCP2\Data\ProdPilot.mdf'',   MOVE ''Prod_Log'' TO ''K:\Program Files\Microsoft SQL Server\MSSQL$LCP2\Data\ProdPilot_log.ldf'' '
	,@zippath = NULL

SELECT * FROM LogShipping_Audit


--USE Prod
GO
SELECT * FROM tmp
