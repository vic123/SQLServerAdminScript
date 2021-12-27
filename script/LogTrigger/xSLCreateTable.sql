
DROP TABLE xSLog
go

CREATE TABLE xSLog (
       ID                   int IDENTITY,
       Action               char NOT NULL,
       Statement            nvarchar(4000) NULL,
       UserName             sysname NOT NULL,
       DateTime             datetime NOT NULL,
       TableName            nvarchar(392) NOT NULL,
       PKFields             nvarchar(4000) NULL,
       NewPKValues          nvarchar(4000) NOT NULL,
       OldPKValues          nvarchar(4000) NULL,
       SPNestedLevel        tinyint NOT NULL,
       TrigNestedLevel      tinyint NOT NULL,
       SrvProcessID         smallint NOT NULL,
       IsDummy              bit NOT NULL
)
go


ALTER TABLE xSLog
       ADD PRIMARY KEY (ID)
go


DROP TABLE xSLText
go

CREATE TABLE xSLText (
       ID                   int IDENTITY,
       Value                text NULL
)
go


ALTER TABLE xSLText
       ADD PRIMARY KEY (ID)
go


DROP TABLE xSLNText
go

CREATE TABLE xSLNText (
       ID                   int IDENTITY,
       Value                ntext NULL
)
go


ALTER TABLE xSLNText
       ADD PRIMARY KEY (ID)
go


DROP TABLE xSLImage
go

CREATE TABLE xSLImage (
       ID                   int NOT NULL,
       Value                image NULL
)
go


ALTER TABLE xSLImage
       ADD PRIMARY KEY (ID)
go


DROP TABLE xSLTypeHelper
go

CREATE TABLE xSLTypeHelper (
       TypeName             sysname NOT NULL,
       BLOBTable            nvarchar(392) NULL,
       IsBLOB               bit NOT NULL,
       HasPrec              bit NOT NULL,
       HasScale             bit NOT NULL,
       CharConvPref         varchar(100) NULL,
       HasLength            bit NULL,
       CharConvPost         varchar(100) NULL
)
go


ALTER TABLE xSLTypeHelper
       ADD PRIMARY KEY (TypeName)
go



