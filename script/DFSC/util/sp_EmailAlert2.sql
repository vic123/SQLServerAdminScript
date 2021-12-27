DROP PROCEDURE sp_EmailAlert2
go
CREATE PROCEDURE sp_EmailAlert2
@ModuleName Varchar(200),
--(051126) @Msg Varchar(500) = NULL,
@Msg nVarchar(4000) = NULL,
@CcList Varchar(1500)=NULL

AS
declare @rc int
/*
exec @rc = master.dbo.xp_smtp_sendmail
     @FROM   = N'kukareku@infoplanet-usa.com',
     @TO     = N'vlad@infoplanet-usa.com',
     @CC     = @CcList,
    --@attachments= N'D:\PopulateDatamartErrorLog.txt',
    @Subject = @ModuleName,
    @Message = @Msg,
    @Server = N'189.4.167.44'
*/
SELECT @ModuleName, @Msg, @CcList
GO 
