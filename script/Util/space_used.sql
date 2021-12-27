CREATE TABLE #TemptableforspaceUsed
(name SYSNAME,
rows INT,
reserved VARCHAR(10),
data VARCHAR(10),
index_size VARCHAR(10),
unused VARCHAR(10))
GO
INSERT #TemptableforspaceUsed
EXEC sp_MSforeachtable 'sp_spaceused ''?'''
