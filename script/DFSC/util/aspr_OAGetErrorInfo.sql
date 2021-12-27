DROP FUNCTION aspr_OAGetErrorInfo
go
CREATE FUNCTION aspr_OAGetErrorInfo (@object  int,  @hresult int)
--	@output  nvarchar(4000) OUT
RETURNS 	nvarchar(4000)
AS BEGIN
	DECLARE  @output	nvarchar(4000)
	DECLARE  @hrhex       char(10)
	DECLARE  @hr          int
	DECLARE  @source      varchar(255)
	DECLARE  @description varchar(255)


--	PRINT   'OLE Automation Error Information'
	SELECT @hrhex = dbo.audf_VarBinary2Hex(@hresult)
	SELECT  @output = 'HRESULT: ' + isNull(@hrhex, 'NULL')

	EXEC    @hr = sp_OAGetErrorInfo @object, @source OUTPUT, @description OUTPUT

	IF  @hr = 0
	BEGIN
	   SELECT @output = @output + ' Source: ' + isNull(@source, 'NULL')
	   SELECT @output = @output + ' Description: ' + isNull(@description, 'Null')	
	END ELSE SELECT @output = @output + ' sp_OAGetErrorInfo failed, unable to get error source and description.'
	RETURN (@output)
END
GO

