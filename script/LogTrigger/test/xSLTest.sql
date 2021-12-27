DROP TABLE LogTest
go

CREATE TABLE LogTest (
       LogTestID            int NOT NULL,
       fBinary10            binary(10) NULL,
       fBit                 bit NULL,
       fChar_18             char(18) NULL,
       fDateTime            datetime NULL,
       fDecimal_10_3        decimal(10,3) NULL,
       fFloat_20            real NULL,
       fFloat_50            float NULL,
       fInt                 int NULL,
       fMoney               money NULL,
       fNChar               nchar(20) NULL,
       fNumeric             numeric NULL,
       fNVarchar            nvarchar(20) NULL,
       fReal                real NULL,
       fSmallDatetime       smalldatetime NULL,
       fSmallInt            smallint NULL,
       fSmallMoney          smallmoney NULL,
       fSysName             sysname NULL,
       fTimestamp           timestamp NULL,
       fTinyint             tinyint NULL,
       fUniqueIdentifier    uniqueidentifier NULL,
       fVarbinary_200       varbinary(200) NULL,
       fVarchar_200         varchar(200) NULL,
       fBinary_200          binary(200) NULL--,
--		fImage				image,
--		fText				text
)
go


ALTER TABLE LogTest
       ADD PRIMARY KEY CLUSTERED (LogTestID)
go


--up_GenerateSLTrigger LogTest

SET NOCOUNT ON
delete from LogTestPK 
--delete from xStatementLog 
insert into LogTestPK (LogTestID, fBinary10, fBit, fChar_18, fDateTime, 
			fDecimal_10_3, fFloat_20, fFloat_50, 
			fInt, fMoney, fNChar, 
			fNumeric, fNVarchar, fReal, fSmallDatetime, fSmallInt, fSmallMoney, 
			fSysName, 
			fTimestamp, fTinyint, fUniqueIdentifier, fVarbinary_200, 
			fVarchar_200, fBinary_200)
	select 1, (select max(first) from sysindexes), 1, 'al''ba''la', '2001-12-12 08:15', 
		12345.679456, 12345.679456, 12345.679456, 
	--	(select definition from master..syscharsets where id = 1),
		12345, 12345.679456, 'î', 
		12345.679456, 'î Ü', 12345.679456, '2001-12-12 08:15', 12345.679456, 12345.679456, 
		'asdsdaf af fd sdf sdf sd', 
		null, 123, newid(), (select max(sid) from master..sysprocesses), 
		'asdsdaf af fd sdf sdf sd', (select max(sid) from master..sysprocesses)
	from master..syscharsets where id = 1

declare @ilog_id int, @ulog_id int, @dlog_id int
select @ilog_id = @@IDENTITY
--select '@ilog_id = ' + cast(@log_id as varchar(10))

print '************** Originally inserted record: ****************'
select * from LogTestPK where LogTestID = 1
delete from LogTestPK where LogTestID = 1

declare @stnmt varchar(8000)
select @stnmt = xSLStatement from xStatementLog where xStatementLogID = @ilog_id
print '************** INSERT Log record: **********************'
select xStatementLogID, xSLAction, xSLUserName, xSLDateTime, xSLTable, xSLPKFields, xSLPKValues, xSLNestedLevel, xSLNestedTrigger, xSLServerProcessID, xSLisDummy
from xStatementLog where xStatementLogID = @ilog_id
print @stnmt
exec (@stnmt)
print '************** Record inserted from log: *******************'
select * from LogTestPK where LogTestID = 1

UPDATE LogTestPK SET 
LogTestID = 100,
fBinary10 = (select min(first) from sysindexes),
fBit = 2,
fChar_18 = 'alabala-kukuru',
fDateTime = '2002-09-12 16:45', 
fDecimal_10_3 = 9876.54321,
fFloat_20 = 9876.54321,
fFloat_50 =  9876.54321,
fInt = 9876, 
fMoney = 9876.54321,
fNChar = 'xad', 
fNumeric = 9876.54321,
fNVarchar = '_ldskjfsd',
fReal = 9876.54321, 
fSmallDatetime = '2031-09-25 08:15',
fSmallInt = 567,
fSmallMoney = 9876.54321, 
fSysName = 'asasl;kdaslkd', 
--fTimestamp = null,
fTinyint = 123, 
fUniqueIdentifier = newid(), 
fVarbinary_200 =  (select min(sid) from master..sysprocesses),  
fVarchar_200 = 'dfsalkjj', 
fBinary_200 = (select min(sid) from master..sysprocesses)

select @ulog_id = @@IDENTITY
print '************** Directly updated record that was inserted from log: *******************'
select * from LogTestPK where LogTestID = 100

delete from LogTestPK

print '************** UPDATE Log record: **********************'
select xStatementLogID, xSLAction, xSLUserName, xSLDateTime, xSLTable, xSLPKFields, xSLPKValues, xSLNestedLevel, xSLNestedTrigger, xSLServerProcessID, xSLisDummy
from xStatementLog where xStatementLogID = @ulog_id
select @stnmt = xSLStatement from xStatementLog where xStatementLogID = @ilog_id
exec (@stnmt)
select @stnmt = xSLStatement from xStatementLog where xStatementLogID = @ulog_id
print @stnmt
exec (@stnmt)
print '************** Record inserted and updated from log: *******************'
select * from LogTestPK where LogTestID = 100

DELETE from LogTestPK 
select @dlog_id = @@IDENTITY
print '************** DELETE Log record: **********************'
select xStatementLogID, xSLAction, xSLUserName, xSLDateTime, xSLTable, xSLPKFields, xSLPKValues, xSLNestedLevel, xSLNestedTrigger, xSLServerProcessID, xSLisDummy
from xStatementLog where xStatementLogID = @dlog_id
select @stnmt = xSLStatement from xStatementLog where xStatementLogID = @dlog_id
print @stnmt





