1. Create LogShipping DB on primary and standby servers
2. Run "logshipping - server1 - source - scripts.sql" on primary server
3. Run "logshipping - server2 - destination - scripts.sql" on standby server.
4. Edit(fix parameters) and run Test_Server1.sql on primary 
5. Edit(fix parameters) and run Test_Server2.sql on standby 



1. Run errlog\SQLErrLog_script.tmp.sql in LogShipping DB
2. Run aspr_LSHP_XCopy.sql  in LogShipping DB
3. Setup SQL Agent job for 
aspr_LSHP_XCopy 'D:\Documents\*' '\\backupSrv\shared\Documents' 