# SQLServerAdminScript - imported from discontinued codeplex.com.
Code and readme content below are very old, dated by around 2005. Project did not evolve beyond initial commit.

## **Project Description**
Collection of T-SQL (mostly) scripts with centralized logging and emailing allowing quick configuration of backup, free space control, operations with files, custom log shipping, audit, lock tracing.
Plus other useful utilities and libraries found around in the web.


### **I. Project Goal:**
Compose and maintenance of easy to download and install pack of qualified and mutually integrated scripts helpful in implementation of strategic administrative objectives and carrying out of ongoing database support tasks.

### **II. Project Base:**
### Collection of production-used solutions:
BTR (Block Tracing Runtime) (SQL 2000) - set of stored procedures that save available system info (sysprocesses, syslocks, syslockinfo, DBCC INPUTBUFFER, sysjobhistory) on each blocked or blocking SQL server process at given time intervals. It has features of optional conditional killing of suspicious blocking processes, configurable and automated control over self-consumed machine resources, selectivity of system info to be saved, and concise report output allowing quick identification of lock queues with supplementary info on each process involved.

LogTrigger (SQL 7 & 2000) – generator of triggers logging table data modifications. Log of data changes is saved into single table-structure in form of runnable DML statements. Handles multiple-row updates, supports user-defined types, can save new BLOB data from inserts and updates.

LogShipping (SQL 2000) – Chris Kempster’s custom log shipping implementation with some minor add-ons like logging and explicit killing of user connections on destination server, supports zipping of backups and email notifications. 

EMail (SQL 2000) – decoration of either CDOSys or xp_smtp_sendmail, capable to send emails larger than 8000 bytes.

ErrLog (SQL 2000) - framework for unified handling of errors and trace messages in stored procedures, stores all contextual system info, capable to keep log from inside of rollbacked transaction. Integrated with SendMail, it can email selective set of log records filtered by starting statement, process ID, log message severity, time period and patterns of log messages.

DFSC (DrivesFreeSpaceControl) (SQL 2000) – controls parameterized per drive amount of minimal free space, takes care of parameterized per database log files size and parameterized per directory deleting of outdated backups or temporary files by file age, sends notifications by email. Integrated with ErrLog, records detailed execution traces and log errors. 

Backup&RestoreDBList (SQL 2000) – stored procedures for backup and restore of list of databases. Backup parameters include type of backup and location for each listed database, restore – backup files mask (full and log backups) for each database. Integrated with ErrLog.

ProcessFiles (SQL 2000) – code taking care for recursive listing of files and calling custom code "plugins" supplied in parameters upon different events of file-listing process. Included "plugins" are for daily zipping, copying, deleting, recursive zip listing, unzipping, and storing of info on files in database. Integrated with ErrLog.

Other smaller utility scripts and procedures ever wrote or re-factored from public ones, may be plus some sample documentation of processing scenarios, system configurations, etc.

Third-party libraries and utilities proven to be workable and useful.

### **III. Specific "administrative code" principles**
Language – if possible code to be developed in T-SQL, if it is not possible or extremely ineffective then with some other scripting approach not requiring compilation.

Integration - if possible then no binary executables to be involved, if not then preference to be given for free opensource applications, components of Windows system or standard MS packs.

Environment – if possible, not extremely complicated and confirms to script appliance, then code and any data has to be capable to reside in single pre-defined database and to be executed in context of any other database.

Execution – code has to be designed for unattended execution with intensive tracing, error logging and automated notifying. 

Naming convention – preferred naming convention specification may become part of the project, however newly added third-party scripts or code appended to existing scripts should follow script’s original naming. Otherwise naming in whole script has to be reworked.

### **IV. Strategic Tasks:**

Keep code compatible with new SQL Server versions.

Improve code internal integration and conformity to declared principals.

Continuously observe web forums and publications and integrate more scripts extending pack’s functionality.

## Current project state:
In short – just initial snapshot of differently aged files. Requires some more work in order to become a release.

Specific scripts ran in SQL Server 2000 production environment and can be assumed stable enough. Only some latest work around large emails and files processing could break something.

Committed files are not tested thoroughly for completeness. Please notify if something is missing.

Current mutual integration is weak. Some utility files are repeated under different names.

All (or at least nearly all) third-party code is with preserved origination comments. Not sure yet about formal contact procedure with other authors for appealing on permission of code packaging/reuse. Prefer it to be performed when project acquire some better view.

Major part of documentation is not re-worked and published yet. Lot of comments and tests are not in presentable form as well.

#### _Special thanks to Vlad Isaev, under whose supervision and active participation most of project base scripts were developed initially._

