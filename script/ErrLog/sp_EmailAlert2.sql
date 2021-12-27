IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[sp_EmailAlert2]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
	DROP PROCEDURE dbo.sp_EmailAlert2
go
CREATE PROCEDURE sp_EmailAlert2
@ModuleName Varchar(200),
@Msg nVarchar(4000) = NULL,
@CcList Varchar(1500)=NULL

AS
declare @rc int
/*
exec @rc = master.dbo.xp_smtp_sendmail
     @FROM   = N'kuku@kuku.com',
     @TO     = N'dodo@dodo.com',
     @CC     = @CcList,
    --@attachments= N'D:\first.txt',
    @Subject = @ModuleName,
    @Message = @Msg,
    @Server = N'192.168.101.01'
*/
SELECT @ModuleName, @Msg, @CcList
GO 
