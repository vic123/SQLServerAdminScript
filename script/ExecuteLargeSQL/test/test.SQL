DROP table t_SMove
go
  CREATE TABLE t_SMove (
       SMid                 int NOT NULL primary key,
       SMText               text,
       SDid                 int NOT NULL,
       SMNo                 int NOT NULL,
       SCCDtID              int NULL,
       SPDtMoveNo           int NULL,
       SCCDtSum             decimal(24,4) NULL,
       SCCDtAmount          decimal(24,4) NULL,
       SCCDtWMTid	    int NULL,
       SCCDtWMid	    int NULL,
       SCCDtWAmount         decimal(24,4) NULL,
       SCCDtPAmount         decimal(24,4) NULL,
       SCCDtFAid            int NULL,
       SCCDtFPid            int NULL,
       SCCDtIZNo            int NULL,
       SCCDtWIZNo           int NULL,
       SCCDtIZYear            int NULL,
       SCCDtWIZYear            int NULL,
       SCCDtEGN             varchar(10) NULL,
       SCCisDt              tinyint NOT NULL,
       SPDtID               int NULL,
       SPSCDtID             int NULL,
       SPDtNo               int NULL,
       SPDtMUid             int NULL,
       SPDtPSize            decimal(24,4) NULL,
       SPPDtID              int NULL,
       SPPDtNo              int NULL,
       SPPDtText            varchar(15),
       SPPDtMid             int NULL,
       SPPDtSeria           varchar(20) NULL,
       SPPDtEndDate         datetime NULL,
       SPPDtInvNo           int NULL,
       SCCCtID              int NULL,
       SPCtMoveNo           int NULL,
       SCCCtSum             decimal(24,4) NULL,
       SCCCtAmount          decimal(24,4) NULL,
       SCCCtWMTid	    int NULL,
       SCCCtWMid	    int NULL,
       SCCCtWAmount         decimal(24,4) NULL,
       SCCCtPAmount         decimal(24,4) NULL,
       SCCCtFAid            int NULL,
       SCCCtFPid            int NULL,
       SCCCtIZNo            int NULL,
       SCCCtWIZNo            int NULL,
       SCCCtIZYear          int NULL,
       SCCCtWIZYear          int NULL,
       SCCCtEGN             varchar(10) NULL,
       SCCisCt              tinyint NOT NULL,
       SPCtID               int NULL,
       SPSCCtID             int NULL,
       SPCtNo               int NULL,
       SPCtMUid             int NULL,
       SPCtPSize            decimal(24,4) NULL,
       SPPCtID              int NULL,
       SPPCtNo              int NULL,
       SPPCtText            varchar(15),
       SPPCtMid             int NULL,
       SPPCtSeria           varchar(20) NULL,
       SPPCtEndDate         datetime NULL,
       SPPCtInvNo           int NULL
  )

--create table #stmnt (stmnt text)
--insert into #stmnt VALUES ('')
--SELECT substring(stmnt, 1, 10) from #stmnt

declare loan_cur cursor for
SELECT sc.NAME, sc.status
	FROM syscolumns sc join sysobjects so on sc.id = so.id
	WHERE so.name = 't_SMove'
	order by sc.name

create table #stmnt (stmnt text)
insert into #stmnt VALUES ('INSERT INTO t_SMove (')
open loan_cur
declare @colname sysname, @colstatus tinyint, @first_run int
declare @ptrval  varbinary(16), @ptrlen int
SELECT @ptrval = TEXTPTR(stmnt) FROM #stmnt
SELECT @first_run = 1
FETCH FIRST FROM loan_cur INTO @colname, @colstatus
WHILE (@@FETCH_STATUS = 0) BEGIN
	IF (@first_run = 0) BEGIN
		select @ptrlen = DATALENGTH(stmnt) from #stmnt
		UPDATETEXT #stmnt.stmnt @ptrval @ptrlen 0 ', '
	END
	select @ptrlen = DATALENGTH(stmnt) from #stmnt
	UPDATETEXT #stmnt.stmnt @ptrval @ptrlen 0 @colname
	FETCH NEXT FROM loan_cur INTO @colname, @colstatus
	SELECT @first_run = 0
END
select @ptrlen = DATALENGTH(stmnt) from #stmnt
UPDATETEXT #stmnt.stmnt @ptrval @ptrlen 0 ') SELECT '

SELECT @first_run = 1
FETCH FIRST FROM loan_cur INTO @colname, @colstatus
WHILE (@@FETCH_STATUS = 0) BEGIN
	IF (@first_run = 0) BEGIN
		select @ptrlen = DATALENGTH(stmnt) from #stmnt
		UPDATETEXT #stmnt.stmnt @ptrval @ptrlen 0 ', '
	END
	select @ptrlen = DATALENGTH(stmnt) from #stmnt
	UPDATETEXT #stmnt.stmnt @ptrval @ptrlen 0 @colname
	FETCH NEXT FROM loan_cur INTO @colname, @colstatus
	SELECT @first_run = 0
END
select @ptrlen = DATALENGTH(stmnt) from #stmnt
UPDATETEXT #stmnt.stmnt @ptrval @ptrlen 0 ' FROM t_SMove '

exec executelargesql @tablename = '#stmnt', @fieldname = 'stmnt'--, @where = '1=1'

SELECT * from #stmnt
select DATALENGTH(stmnt) from #stmnt

close loan_cur
deallocate loan_cur
drop table #stmnt
