exec sp_attach_db @dbname = 'Prod', @filename1 = 'K:\Program Files\Microsoft SQL Server\MSSQL\Data\Pilot.mdf'


set @vbackupdevice = @p_database + '_' + convert(varchar, getdate(), 104) + '_' + convert(varchar, getdate(), 108)
EXEC master..sp_addumpdevice 'disk', 'Prod_logrecovery_backdevice', 'K:\Program Files\Microsoft SQL Server\MSSQL\Data\Prod_trn.bak'
BACKUP LOG Prod TO Prod_logrecovery_backdevice WITH NO_TRUNCATE

