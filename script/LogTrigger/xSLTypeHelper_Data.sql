delete from xSLTypeHelper
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('bigint','',0,0,0,0,'isnull(convert (varchar(50),','), ''null'')')
--060329 insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('binary','',0,0,0,1,'isnull(null+',', ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('binary','',0,0,0,1,'isnull(convert (varchar(8000),','), ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('bit','',0,0,0,0,'isnull(convert (varchar(6),','), ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('char','',0,0,0,1,'isnull(''''''''+','+'''''''', ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('datetime','',0,0,0,0,'isnull(''convert(datetime, '''''' + convert(varchar, ',', 100) + '''''', 100)'', ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('decimal','',0,1,1,0,'isnull(convert (varchar(50), ','), ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('float','',0,1,0,0,'isnull(convert (varchar(100), ','), ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('image','xSLImage',1,0,0,0,'','')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('int','',0,0,0,0,'isnull(convert (varchar(20),','), ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('money','',0,0,0,0,'isnull(convert (varchar(30), ','), ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('nchar','',0,0,0,1,'isnull(''''''''+','+'''''''', ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('ntext','xSLNText',1,0,0,0,'','')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('numeric','',0,1,1,0,'isnull(convert (varchar(50), ','), ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('nvarchar','',0,0,0,1,'isnull(''''''''+','+'''''''', ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('real','',0,0,0,0,'isnull(convert (varchar(100), ','), ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('smalldatetime','',0,0,0,0,'isnull(''convert(datetime, '''''' + convert(varchar, ',', 100) + '''''', 100)'', ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('smallint','',0,0,0,0,'isnull(convert (varchar(10),','), ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('smallmoney','',0,0,0,0,'isnull(convert (varchar(30), ','), ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('sysname','',0,0,0,0,'isnull(''''''''+','+'''''''', ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('text','xSLText',1,0,0,0,'','')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('timestamp','',0,0,0,0,'isnull(convert (varchar(30), convert (int, ',')), ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('tinyint','',0,0,0,0,'isnull(convert (varchar(5),','), ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('uniqueidentifier','',0,0,0,0,'isnull('''' + convert (varchar(50), ',') + '''', ''null'')')
--060329insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('varbinary','',0,0,0,1,'isnull(null+',', ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('varbinary','',0,0,0,1,'isnull(convert (varchar(8000),','), ''null'')')
insert into xSLTypeHelper (TypeName, BLOBTable, IsBLOB, HasPrec, HasScale, HasLength, CharConvPref, CharConvPost) values ('varchar','',0,0,0,1,'isnull(''''''''+','+'''''''', ''null'')')
