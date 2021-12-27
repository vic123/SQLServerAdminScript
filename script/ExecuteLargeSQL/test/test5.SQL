DROP table t_SMove
go
  CREATE TABLE t_SMove (
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
       SMid                 int NOT NULL,
       SPPDtID              int NULL,
  )
go

insert into t_SMove (SMid, SMText,   SDid, SMNo, SCCisDt )
VALUES (1, 'lalabala', 2, 3, 0)


--create table #stmnt (stmnt text)
--insert into #stmnt VALUES ('')
--SELECT substring(stmnt, 1, 10) from #stmnt

declare loan_cur cursor for

/*
UPDATE syscolumns SET colid = 27 
FROM sysobjects so WHERE 
syscolumns.id = so.id
AND so.name = 't_SMove'
AND	colid = 1
*/

SELECT sc.NAME, sc.status
	FROM syscolumns sc join sysobjects so on sc.id = so.id
	WHERE so.name = 't_SMove'
--	order by sc.name
	order by sc.colid

declare @sql1 varchar(255), @sql2 varchar(255), @sql3 varchar(255), @sql4 varchar(255), @sql5 varchar(255)

--select @sql1 = 'INSERT INTO t_SMove ('
select @sql1 = 'INSERT INTO t_SMove '
declare @colname sysname, @colstatus tinyint, @first_run int

open loan_cur 
SELECT @first_run = 1
FETCH FIRST FROM loan_cur INTO @colname, @colstatus
WHILE (@@FETCH_STATUS = 0) BEGIN
	IF (@first_run = 0) BEGIN
		SELECT @sql2 = @sql2 + ','
		SELECT @sql4 = @sql4 + ','
	END
	SELECT @sql2 = @sql2 + @colname
	SELECT @sql4 = @sql4 + @colname
	FETCH NEXT FROM loan_cur INTO @colname, @colstatus
	SELECT @first_run = 0
END
--SELECT @sql3 = @sql3 + ') SELECT '
SELECT @sql3 = @sql3 + ' SELECT '
SELECT @sql5 = @sql5 + ' FROM t_SMove '

--exec (@sql1 + @sql2 + @sql3 + @sql4 + @sql5) 
exec (@sql1 + @sql3 + @sql4 + @sql5) 

select @sql1, @sql2, @sql3, @sql4, @sql5
select * from t_SMove

close loan_cur
deallocate loan_cur


