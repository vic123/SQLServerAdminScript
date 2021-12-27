			select max(seq), dbtype, lastfilename 
			from LogShipping_Audit 
			where 
--dbname = @dbname
--			and	
lastfilename is not null
			and status = 'SUCCESS'
			-- to do, check for ERROR between last full/diff and current
			group by dbtype, lastfilename 
			order by 1 desc


SELECT * FROM LogShipping_Audit order by seq
SELECT * INTO LogShipping_Audit_bak1 FROM LogShipping_Audit  

DROP TABLE LogShipping_Audit
SELECT * INTO LogShipping_Audit FROM LogShipping_Audit_bak1

DELETE LogShipping_Audit 
