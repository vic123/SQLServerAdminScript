
if exists (select * from sysobjects where name = 'btr_syslockinfo_tmp' and type = 'U')
DROP TABLE btr_syslockinfo_tmp
go

if exists (select * from sysobjects where name = 'btr_DBCCINB_tmp' and type = 'U')
DROP TABLE btr_DBCCINB_tmp
go

if exists (select * from sysobjects where name = 'btr_sysprocesses_tmp' and type = 'U')
DROP TABLE btr_sysprocesses_tmp
go

if exists (select * from sysobjects where name = 'btr_Params' and type = 'U')
DROP TABLE btr_Params
go

if exists (select * from sysobjects where name = 'btr_PHistory' and type = 'U')
DROP TABLE btr_PHistory
go

if exists (select * from sysobjects where name = 'btr_DBCCINB' and type = 'U')
DROP TABLE btr_DBCCINB
go

if exists (select * from sysobjects where name = 'btr_syslockinfo' and type = 'U')
DROP TABLE btr_syslockinfo
go

if exists (select * from sysobjects where name = 'btr_sysprocesses' and type = 'U')
DROP TABLE btr_sysprocesses
go

if exists (select * from sysobjects where name = 'btr_LOG' and type = 'U')
DROP TABLE btr_LOG
go

if exists (select * from sysobjects where name = 'btr_sysjobhistory' and type = 'U')
DROP TABLE btr_sysjobhistory
go

/*debug tables section begin */
if exists (select * from sysobjects where name = 'btr_sysprocessesCnt_debug' and type = 'U')
DROP TABLE btr_sysprocessesCnt_debug
go

if exists (select * from sysobjects where name = 'btr_sysprocessesCur_debug' and type = 'U')
DROP TABLE btr_sysprocessesCur_debug
go

if exists (select * from sysobjects where name = 'btr_sysprocessesIns_debug' and type = 'U')
DROP TABLE btr_sysprocessesIns_debug
go

/*debug tables section end */

if exists (select * from sysobjects where name = 'btr_Batch' and type = 'U')
DROP TABLE btr_Batch
go

if exists (select * from sysobjects where name = 'CurrentDateTime' and type = 'D')
drop DEFAULT CurrentDateTime
go

declare syso_cur cursor for select name from sysobjects where name like 'btr_sjh_dbg%' and type = 'U'
open syso_cur
declare @btrt_name varchar (100)
while (1= 1) begin
	fetch next from syso_cur into @btrt_name
	if (@@fetch_status <> 0) break
	exec ('drop table ' + @btrt_name)
end
close syso_cur
deallocate syso_cur
go

CREATE DEFAULT CurrentDateTime
	AS GETDATE()
go


CREATE TABLE btr_Batch (
       b_id                 int IDENTITY,
       time_beg             datetime NOT NULL,
       time_end             datetime NULL
)
go


ALTER TABLE btr_Batch
       ADD PRIMARY KEY (b_id)
go

CREATE INDEX XIEbtr_Batch_TimeBeg ON btr_Batch
(
       time_beg
)
go

CREATE INDEX XIEbtr_Batch_TimeEnd ON btr_Batch
(
       time_end
)
go

exec sp_bindefault CurrentDateTime, 'btr_Batch.time_beg'
go

CREATE TABLE btr_DBCCINB (
       dbccinb_id           int IDENTITY,
       sp_id                int NOT NULL,
       b_id_beg             int NOT NULL,
       b_id_end             int NULL,
       EventType            nvarchar(30) NULL,
       Parameters           int NULL,
       EventInfo            nvarchar(255) NULL
)
go

CREATE INDEX XIF23btr_DBCCINB ON btr_DBCCINB
(
       sp_id
)
go

CREATE INDEX XIF24btr_DBCCINB ON btr_DBCCINB
(
       b_id_end
)
go

CREATE INDEX XIF25btr_DBCCINB ON btr_DBCCINB
(
       b_id_beg
)
go


ALTER TABLE btr_DBCCINB
       ADD PRIMARY KEY (dbccinb_id)
go


CREATE TABLE btr_LOG (
       log_id               int IDENTITY,
       b_id                 int NOT NULL,
       msg                  nvarchar(255) NULL,
       time                 datetime NOT NULL
)
go

CREATE INDEX XIF22btr_LOG ON btr_LOG
(
       b_id
)
go


ALTER TABLE btr_LOG
       ADD PRIMARY KEY (log_id)
go


exec sp_bindefault CurrentDateTime, 'btr_LOG.time'
go

CREATE TABLE btr_Params (
       Name                 nvarchar(30) NOT NULL,
       ph_id                int NOT NULL,
       Value                nvarchar(30) NOT NULL
)
go


CREATE INDEX XIFbtr_ParamsPH_ID ON btr_Params
(
       ph_id
)
go


ALTER TABLE btr_Params
       ADD PRIMARY KEY (ph_id, Name)
go


CREATE TABLE btr_PHistory (
       ph_id                int IDENTITY,
       time                 datetime NULL,
       action               varchar(20) NULL,
       uname                varchar(128) NULL
)
go

ALTER TABLE btr_PHistory
       ADD PRIMARY KEY (ph_id)
go


CREATE TABLE btr_syslockinfo (
       sl_id                int NOT NULL,
       rsc_text             nchar(32) NOT NULL,
       b_id_beg             int NOT NULL,
       rsc_bin              binary(16) NOT NULL,
       b_id_end             int NULL,
       rsc_valblk           binary(16) NOT NULL,
       rsc_dbid             smallint NOT NULL,
       rsc_indid            smallint NOT NULL,
       rsc_objid            int NOT NULL,
       rsc_type             tinyint NOT NULL,
       rsc_flag             tinyint NOT NULL,
       req_mode             tinyint NOT NULL,
       req_status           tinyint NOT NULL,
       req_refcnt           smallint NOT NULL,
       req_cryrefcnt        smallint NOT NULL,
       req_lifetime         int NOT NULL,
       req_spid             int NOT NULL,
       req_ecid             int NOT NULL,
       req_ownertype        smallint NOT NULL,
       req_transactionID    bigint NULL,
       req_transactionUOW   uniqueidentifier NULL
)
go

CREATE INDEX XIF26btr_syslockinfo ON btr_syslockinfo
(
       b_id_end
)
go

CREATE INDEX XIF27btr_syslockinfo ON btr_syslockinfo
(
       b_id_beg
)
go


ALTER TABLE btr_syslockinfo
       ADD PRIMARY KEY (sl_id)
go


CREATE TABLE btr_syslockinfo_tmp (
       sl_id                int IDENTITY,
       rsc_text             nchar(32) NOT NULL,
       b_id_beg             int NOT NULL,
       rsc_bin              binary(16) NOT NULL,
       b_id_end             int NULL,
       rsc_valblk           binary(16) NOT NULL,
       rsc_dbid             smallint NOT NULL,
       rsc_indid            smallint NOT NULL,
       rsc_objid            int NOT NULL,
       rsc_type             tinyint NOT NULL,
       rsc_flag             tinyint NOT NULL,
       req_mode             tinyint NOT NULL,
       req_status           tinyint NOT NULL,
       req_refcnt           smallint NOT NULL,
       req_cryrefcnt        smallint NOT NULL,
       req_lifetime         int NOT NULL,
       req_spid             int NOT NULL,
       req_ecid             int NOT NULL,
       req_ownertype        smallint NOT NULL,
       req_transactionID    bigint NULL,
       req_transactionUOW   uniqueidentifier NULL
)
go

CREATE INDEX XIF35btr_syslockinfo_tmp ON btr_syslockinfo_tmp
(
       b_id_end
)
go

CREATE INDEX XIF36btr_syslockinfo_tmp ON btr_syslockinfo_tmp
(
       b_id_beg
)
go


ALTER TABLE btr_syslockinfo_tmp
       ADD PRIMARY KEY (sl_id)
go


CREATE TABLE btr_sysprocesses (
       sp_id                int NOT NULL,
       spid                 smallint NOT NULL,
       b_id_beg             int NOT NULL,
       kpid                 smallint NOT NULL,
       b_id_end             int NULL,
       blocked              smallint NOT NULL,
       waittype             binary(2) NOT NULL,
       waittime             int NOT NULL,
       lastwaittype         nchar(32) NOT NULL,
       waitresource         nchar(256) NOT NULL,
       dbid                 smallint NOT NULL,
       uid                  smallint NOT NULL,
       cpu                  int NOT NULL,
       physical_io          bigint NOT NULL,
       memusage             int NOT NULL,
       login_time           datetime NOT NULL,
       last_batch           datetime NOT NULL,
       ecid                 smallint NOT NULL,
       open_tran            smallint NOT NULL,
       status               nchar(30) NOT NULL,
       sid                  binary(86) NOT NULL,
       hostname             nchar(128) NOT NULL,
       program_name         nchar(128) NOT NULL,
       hostprocess          nchar(8) NOT NULL,
       cmd                  nchar(16) NOT NULL,
       nt_domain            nchar(128) NOT NULL,
       nt_username          nchar(128) NOT NULL,
       net_address          nchar(12) NOT NULL,
       net_library          nchar(12) NOT NULL,
       loginame             nchar(128) NOT NULL,
       context_info         binary(128) NOT NULL
)
go

CREATE INDEX XIF28btr_sysprocesses ON btr_sysprocesses
(
       b_id_end
)
go

CREATE INDEX XIF29btr_sysprocesses ON btr_sysprocesses
(
       b_id_beg
)
go


ALTER TABLE btr_sysprocesses
       ADD PRIMARY KEY (sp_id)
go


CREATE TABLE btr_sysprocesses_tmp (
       sp_id                int IDENTITY,
       spid                 smallint NOT NULL,
       b_id_beg             int NOT NULL,
       kpid                 smallint NOT NULL,
       b_id_end             int NULL,
       blocked              smallint NOT NULL,
       waittype             binary(2) NOT NULL,
       waittime             int NOT NULL,
       lastwaittype         nchar(32) NOT NULL,
       waitresource         nchar(256) NOT NULL,
       dbid                 smallint NOT NULL,
       uid                  smallint NOT NULL,
       cpu                  int NOT NULL,
       physical_io          bigint NOT NULL,
       memusage             int NOT NULL,
       login_time           datetime NOT NULL,
       last_batch           datetime NOT NULL,
       ecid                 smallint NOT NULL,
       open_tran            smallint NOT NULL,
       status               nchar(30) NOT NULL,
       sid                  binary(86) NOT NULL,
       hostname             nchar(128) NOT NULL,
       program_name         nchar(128) NOT NULL,
       hostprocess          nchar(8) NOT NULL,
       cmd                  nchar(16) NOT NULL,
       nt_domain            nchar(128) NOT NULL,
       nt_username          nchar(128) NOT NULL,
       net_address          nchar(12) NOT NULL,
       net_library          nchar(12) NOT NULL,
       loginame             nchar(128) NOT NULL,
       context_info         binary(128) NOT NULL
)
go

CREATE INDEX XIF33btr_sysprocesses_tmp ON btr_sysprocesses_tmp
(
       b_id_end
)
go

CREATE INDEX XIF34btr_sysprocesses_tmp ON btr_sysprocesses_tmp
(
       b_id_beg
)
go


ALTER TABLE btr_sysprocesses_tmp
       ADD PRIMARY KEY (sp_id)
go


CREATE TABLE btr_sysjobhistory (
       sjh_id               int IDENTITY,
       instance_id          int NOT NULL,
       b_id                 int NOT NULL,
       job_id               uniqueidentifier NOT NULL,
       step_id              int NOT NULL,
       step_name            sysname NOT NULL,
       sql_message_id       int NOT NULL,
       sql_severity         int NOT NULL,
       message              nvarchar(1024) NULL,
       run_status           int NOT NULL,
       run_date             int NOT NULL,
       run_time             int NOT NULL,
       run_duration         int NOT NULL,
       operator_id_emailed  int NOT NULL,
       operator_id_netsent  int NOT NULL,
       operator_id_paged    int NOT NULL,
       retries_attempted    int NOT NULL,
       server               nvarchar(30) NOT NULL
)
go

CREATE INDEX XIF37btr_sysjobhistory ON btr_sysjobhistory
(
       b_id
)
go

CREATE INDEX XIFbtr_sysjobhistory_instance_id ON btr_sysjobhistory
(
       instance_id
)
go

ALTER TABLE btr_sysjobhistory
       ADD PRIMARY KEY (sjh_id)
go

ALTER TABLE btr_DBCCINB
       ADD FOREIGN KEY (b_id_beg)
                             REFERENCES btr_Batch
go


ALTER TABLE btr_DBCCINB
       ADD FOREIGN KEY (b_id_end)
                             REFERENCES btr_Batch
go


ALTER TABLE btr_DBCCINB
       ADD FOREIGN KEY (sp_id)
                             REFERENCES btr_sysprocesses
go


ALTER TABLE btr_LOG
       ADD FOREIGN KEY (b_id)
                             REFERENCES btr_Batch
go


ALTER TABLE btr_Params
       ADD FOREIGN KEY (ph_id)
                             REFERENCES btr_PHistory
go

ALTER TABLE btr_syslockinfo
       ADD FOREIGN KEY (b_id_beg)
                             REFERENCES btr_Batch
go


ALTER TABLE btr_syslockinfo
       ADD FOREIGN KEY (b_id_end)
                             REFERENCES btr_Batch
go


ALTER TABLE btr_syslockinfo_tmp
       ADD FOREIGN KEY (b_id_beg)
                             REFERENCES btr_Batch
go


ALTER TABLE btr_syslockinfo_tmp
       ADD FOREIGN KEY (b_id_end)
                             REFERENCES btr_Batch
go


ALTER TABLE btr_sysprocesses
       ADD FOREIGN KEY (b_id_beg)
                             REFERENCES btr_Batch
go


ALTER TABLE btr_sysprocesses
       ADD FOREIGN KEY (b_id_end)
                             REFERENCES btr_Batch
go


ALTER TABLE btr_sysprocesses_tmp
       ADD FOREIGN KEY (b_id_beg)
                             REFERENCES btr_Batch
go


ALTER TABLE btr_sysprocesses_tmp
       ADD FOREIGN KEY (b_id_end)
                             REFERENCES btr_Batch
go


ALTER TABLE btr_sysjobhistory
       ADD FOREIGN KEY (b_id)
                             REFERENCES btr_Batch
go

/*debug tables section begin */



CREATE TABLE btr_sysprocessesIns_debug (
       sp_id                int IDENTITY,
       b_id                 int NULL,
       spid                 int NULL,
       cpu                  int NULL,
       login_time           datetime NULL
)
go

CREATE INDEX XIF41btr_sysprocessesIns_debug ON btr_sysprocessesIns_debug
(
       b_id
)
go


ALTER TABLE btr_sysprocessesIns_debug
       ADD PRIMARY KEY (sp_id)
go


CREATE TABLE btr_sysprocessesCnt_debug (
       sp_id                int IDENTITY,
       b_id                 int NOT NULL,
       Cnt                  int NULL,
       spid                 int NULL
)
go

CREATE INDEX XIF40btr_sysprocessesCnt_debug ON btr_sysprocessesCnt_debug
(
       b_id
)
go


ALTER TABLE btr_sysprocessesCnt_debug
       ADD PRIMARY KEY (sp_id)
go


CREATE TABLE btr_sysprocessesCur_debug (
       sp_id                int IDENTITY,
       b_id                 int NOT NULL,
       spid                 int NULL,
       cpu                  int NULL,
       login_time           datetime NULL
)
go

CREATE INDEX XIF39btr_sysprocessesCur_debug ON btr_sysprocessesCur_debug
(
       b_id
)
go


ALTER TABLE btr_sysprocessesCur_debug
       ADD PRIMARY KEY (sp_id)
go


ALTER TABLE btr_sysprocessesIns_debug
       ADD FOREIGN KEY (b_id)
                             REFERENCES btr_Batch
go


ALTER TABLE btr_sysprocessesCnt_debug
       ADD FOREIGN KEY (b_id)
                             REFERENCES btr_Batch
go


ALTER TABLE btr_sysprocessesCur_debug
       ADD FOREIGN KEY (b_id)
                             REFERENCES btr_Batch
go




/*debug tables section end */
