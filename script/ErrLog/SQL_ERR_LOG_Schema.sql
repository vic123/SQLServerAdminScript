if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQL_ERR_LOG]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[SQL_ERR_LOG]
GO

CREATE TABLE [dbo].[SQL_ERR_LOG] (
	[ErrId] [int] IDENTITY (1, 1) NOT NULL ,
	[DateTime] [datetime] NOT NULL ,
	[DateDay] [int] NOT NULL ,
	[SystemName] sysname NOT NULL ,     -- <<< -----------
	[AgentName] sysname  NOT NULL ,
	[Statement] [varchar] (255)  NOT NULL ,
	[ErrCode] [int] NULL ,
	[RecordCount] [int] NULL ,
	[LogDesc] [varchar] (5300)  NULL ,
	[SysMessage] [varchar] (500)  NULL ,
	[EMNotify] [varchar] (255)  NULL ,
	[UserId] [sysname] NULL ,
	[DBLoginName] [sysname] NOT NULL ,
	[DBName] [sysname] NOT NULL ,
	[ProcessId] [int] NOT NULL ,
	[NestLevel] [tinyint] NULL ,
	[TranId] [varchar] (255)  NULL ,
	[TranCount] [int] NULL ,
	[IsRollbacked] [bit] NOT NULL ,
	[IsWarnOnly] [bit] NOT NULL ,
	[IsLogOnly] [bit] NOT NULL
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[SQL_ERR_LOG] WITH NOCHECK ADD
	CONSTRAINT [PK__SQL_ERR_LOG__52593CB8] PRIMARY KEY  CLUSTERED
	(
		[ErrId]
	)  ON [PRIMARY]
GO

CREATE  INDEX [SQL_ERR_LOG__TranId] ON [dbo].[SQL_ERR_LOG]([TranId]) ON [PRIMARY]
GO

CREATE  INDEX [SQL_ERR_LOG__DateDay] ON [dbo].[SQL_ERR_LOG]([DateDay]) ON [PRIMARY]
GO

CREATE  INDEX [SQL_ERR_LOG__DateTime] ON [dbo].[SQL_ERR_LOG]([DateTime]) ON [PRIMARY]
GO
CREATE  INDEX [SQL_ERR_LOG__SystemName] ON [dbo].[SQL_ERR_LOG]([SystemName]) ON [PRIMARY]
GO
CREATE  INDEX [SQL_ERR_LOG__AgentName] ON [dbo].[SQL_ERR_LOG]([AgentName]) ON [PRIMARY]
GO
