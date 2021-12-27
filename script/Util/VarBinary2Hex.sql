IF OBJECT_ID('VarBinary2Hex') IS NOT NULL  
  DROP FUNCTION VarBinary2Hex
GO

CREATE FUNCTION VarBinary2Hex (@binValue varbinary(255))
RETURNS varchar(255)
AS BEGIN

	DECLARE   @charvalue varchar(255)
	DECLARE   @i         int
	DECLARE   @length    int
	DECLARE   @hexstring char(16)
	
	SELECT @charvalue = '0x'
	SELECT @i = 1
	SELECT @length = DATALENGTH(@binvalue)
	SELECT @hexstring = '0123456789abcdef'
	
	WHILE (@i <= @length)
	BEGIN
	   DECLARE   @tempint   int
	   DECLARE   @firstint  int
	   DECLARE   @secondint int
	   
	   SELECT @tempint = CONVERT(int, SUBSTRING(@binvalue,@i,1))
	   SELECT @firstint = FLOOR(@tempint/16)
	   SELECT @secondint = @tempint -(@firstint*16)
	   SELECT @charvalue = @charvalue + SUBSTRING(@hexstring, @firstint+1, 1) +
	   SUBSTRING(@hexstring, @secondint+1, 1)
	   SELECT @i = @i + 1
	   
	END
	
	--SELECT @hexvalue = @charvalue
		RETURN ( @charvalue )
END
GO


--SELECT dbo.varBinary2Hex(31)

