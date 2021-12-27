SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[ADM_GET_SYS_MESSAGE]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE dbo.ADM_GET_SYS_MESSAGE
GO


CREATE PROC  dbo.ADM_GET_SYS_MESSAGE
   @in_IntErrorNumber INT ,
   @out_VcErrorString VARCHAR(500) OUTPUT
AS
/**********************************************************************************************
Procedure Name   : GetErrorStringSP 
Author           : Amit Jethva 
Date             : Mar 11 2004 5:30 PM
Purpose          : To get Error Message From SQL Server Error Log using sp
Tables Referred  : 
Input Parameters : 
   1. @in_IntErrorNumber  INT : The error number.
Output Parameters:
   1. @out_VcErrorString VARCHAR(1000) : The Error String from SQL Server Log 
      for current @@SPID and the passed Error number
**********************************************************************************************/

/*MODIFICATIONS HISTORY IN CHRONOLOGICAL ORDER, WITH THE LATEST CHANGE BEING AT THE TOP.*/ 
/******************************************************************************************** 
MODIFIED BY      : 	Victor Blokhin
MODIFICATIONS    : 	no modifications, only tested with and would like to leave as a comment
						SELECT * INTO master.dbo.sysmessages_org FROM master.dbo.sysmessages
						exec sp_configure N'allow updates', 1
						reconfigure with override
						update master.dbo.sysmessages set dlevel = dlevel | 0x80
						exec sp_configure N'allow updates', 0
						reconfigure with override
DATE             :	Mar 2006

MODIFIED BY      : 	Victor Blokhin
MODIFICATIONS    : 	renamed to ADM_GET_SYS_MESSAGE
DATE             :	Mar 2005
**********************************************************************************************/  

BEGIN
   CREATE TABLE #ErrorLog 
   ( 
      SrNo            INT IDENTITY(1,1) NOT NULL ,
      ErrorLogText    VARCHAR(255)      NOT NULL ,
      ContinuationRow INT               NOT NULL 
   )
   
   INSERT INTO #ErrorLog 
   EXEC master.dbo.xp_readerrorlog  


   DECLARE @VcLike1 VARCHAR(255) 
   DECLARE @VcLike2 VARCHAR(255) 
   DECLARE @IntFirstSrNo   INT
   DECLARE @IntLastSrNo    INT 

   SET @VcLike1 = '%spid' + CONVERT(VARCHAR, @@SPID)+ '%Error: %'   + CONVERT (VARCHAR, @in_IntErrorNumber )  + '%'
   SET @VcLike2 = '%spid' + CONVERT(VARCHAR, @@SPID)+ '%Error:%' 
   
   SELECT @IntFirstSrNo    = MAX (SrNo)  FROM #ErrorLog  WHERE ErrorLogText  like @VcLike1 OPTION ( KEEPFIXED PLAN ) 
   SELECT @IntLastSrNo     = MIN (SrNo)  FROM #ErrorLog  WHERE ErrorLogText  like @VcLike2 AND SrNo > @IntFirstSrNo  OPTION ( KEEPFIXED PLAN )   


   IF ISNULL(@IntFirstSrNo, 0 )     =  0 
   BEGIN
--(070412)      SET @out_VcErrorString   = CONVERT (VARCHAR, @in_IntErrorNumber ) + ': NO DESCR AVAILABLE' 
      SET @out_VcErrorString   = CONVERT (VARCHAR(100), @in_IntErrorNumber ) + ': NO DESCR AVAILABLE' 
      RETURN 
   END
   IF ISNULL( @IntLastSrNo , 0 ) =  0 
   BEGIN
      SET @VcLike2 = '%spid' + CONVERT(VARCHAR, @@SPID)+ '%' 
      SELECT @IntLastSrNo     = MAX (SrNo) + 1 FROM #ErrorLog  WHERE ErrorLogText  like @VcLike2 AND SrNo > @IntFirstSrNo    OPTION ( KEEPFIXED PLAN ) 
   END


   SELECT @out_VcErrorString   = ''

--test: SELECT 'Len:' + convert(varchar(100), LEN (isNull(ErrorLogText, '')) - 33)    FROM #ErrorLog ORDER BY convert(varchar(100), LEN (isNull(ErrorLogText, '')) - 33)

   SELECT  @out_VcErrorString   = @out_VcErrorString  + RTRIM( SUBSTRING(ErrorLogText , 34, LEN (ErrorLogText) - 33 ) ) + ' ' 
--(070412)	SELECT  @out_VcErrorString   = @out_VcErrorString  + LTRIM(RTRIM( ErrorLogText))
   FROM #ErrorLog 
   WHERE SrNo BETWEEN  @IntFirstSrNo AND @IntLastSrNo  - 1 
	AND LEN(ErrorLogText) >= 33 --(070412)
	OPTION ( KEEPFIXED PLAN ) 

   -- PRINT @out_VcErrorString     
   SET @out_VcErrorString   = CONVERT (NVARCHAR, @in_IntErrorNumber )  + ': ' + @out_VcErrorString     
END
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


