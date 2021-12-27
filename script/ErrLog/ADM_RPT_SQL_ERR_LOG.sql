
IF EXISTS( SELECT * FROM sysobjects WHERE NAME = 'ADM_RPT_SQL_ERR_LOG' AND TYPE = 'P')
DROP PROC ADM_RPT_SQL_ERR_LOG
GO
CREATE PROCEDURE ADM_RPT_SQL_ERR_LOG(
			@Help		varchar(4) = NULL,		--HELP | '?' - returns brief help on parameters (NULL == none)
			@MinutesAgo int = 1440, 			--"backward" minutes to show log history (1440 == 1 day)
			@AgentName 	varchar(255) = NULL, 	--usually sproc name, can contain wildcard (%,?) characters) (NULL == any)
			@Statement 	varchar(255) = NULL, 	--statement SQL draft, can contain wildcard (%,?) characters) (NULL == any)
			@LogDesc 	varchar(255) = NULL, 	--some business level description, can contain wildcard (%,?) characters) (NULL == any)
			@ErrLevel 	int = 1, 				--0=Log+Warn+Error, 1=Warn+Error, 2=Error (1 == warnings and errors only)
			@Year 		int = NULL,				--FOUR digit year (NULL == current)
			@Month 		int = NULL,				--@Year/@Month/@Day/@Hour/@Minute -
												--		- reported data is between @DateTime - @MinutesAgo 
												--			and @DateTime (NULL == current)
			@Day 		int = NULL,				--""--
			@Hour 		int = NULL,				--""--
			@Minute 	int = NULL,				--""--
			@DateTime 	datetime = NULL			--either @DateTime or @Year/@Month/@Day/@Hour/@Minute can be provided
		) AS 

/**********************************************************************************************
Procedure Name   : ADM_RPT_SQL_ERR_LOG
Author           : Victor Blokhin (vic123.com) & Vlad Isaev (infoplanet-usa.com)
Date             : Mar 2005
Purpose          : Log and error messages reporting procedure
Tables Referred  : 
Input Parameters : EXEC ADM_RPT_SQL_ERR_LOG 'help'
Output Parameters:
**********************************************************************************************/
/*MODIFICATIONS HISTORY IN CHRONOLOGICAL ORDER, WITH THE LATEST CHANGE BEING AT THE TOP.*/ 
/******************************************************************************************** 
MODIFIED BY      : 	
MODIFICATIONS    :	
DATE             :	
**********************************************************************************************/  

/****************************************************************************
Test:
exec ADM_RPT_SQL_ERR_LOG help
exec ADM_RPT_SQL_ERR_LOG '?'
exec ADM_RPT_SQL_ERR_LOG @MinutesAgo = 100000, @ErrLevel = 0, @AgentName = '%CleanRequest_203'
exec ADM_RPT_SQL_ERR_LOG @MinutesAgo = 100000, @ErrLevel = 0, @Year = 2005
*****************************************************************************/

BEGIN
	DECLARE @dbg bit
	SET @dbg = 1
	IF (Upper(@Help) = 'HELP' OR @Help = '?') BEGIN
		PRINT 'PARAMETERS:'
		PRINT 	'@Help          varchar(4) = NULL,		--HELP | ''?'' - returns brief help on parameters (NULL == none)'
		PRINT	'@MinutesAgo    int = 1440, 			--"backward" minutes to show log history (1440 == 1 day)'
		PRINT	'@AgentName     varchar(255) = NULL, 	--usually sproc name, can contain wildcard (%,?) characters) (NULL == any)'
		PRINT	'@Statement     varchar(255) = NULL, 	--statement SQL draft, can contain wildcard (%,?) characters) (NULL == any)'
		PRINT	'@LogDesc       varchar(255) = NULL, 	--some business level description, can contain wildcard (%,?) characters) (NULL == any)'
		PRINT	'@ErrLevel      int = 1, 				--0=Log+Warn+Error, 1=Warn+Error, 2=Error (1 == warnings and errors only)'
		PRINT	'@Year 		int = NULL,					--FOUR digit year (NULL == current)'
		PRINT	'@Month 		int = NULL,				--@Year/@Month/@Day/@Hour/@Minute -'
		PRINT	'										--		- reported data is between @DateTime - @MinutesAgo '
		PRINT	'										--			and @DateTime (NULL == current)'
		PRINT	'@Day           int = NULL,				--""--'
		PRINT	'@Hour          int = NULL,				--""--'
		PRINT	'@Minute        int = NULL,				--""--'
		PRINT	'@DateTime      datetime = NULL			--either @DateTime or @Year/@Month/@Day/@Hour/@Minute can be provided'
		RETURN 0
	END ELSE BEGIN
		PRINT 'For Usage: ADM_RPT_SQL_ERR_LOG HELP | ''?'''
	END
	DECLARE @errmsg nvarchar(255)
	SET @errmsg = 'Either @DateTime or @Year/@Month/@Day/@Hour/@Minute should be provided'
	IF (	@DateTime IS NOT NULL 
			AND (@Year IS NOT NULL 
					OR @Month IS NOT NULL 
					OR @Day IS NOT NULL 
					OR @Hour IS NOT NULL 
					OR @Minute IS NOT NULL
				)
		) GOTO err
	SET @errmsg = '@ErrLevel is constrained to 0=Log+Warn+Error, 1=Warn+Error, 2=Error'
	IF (@ErrLevel NOT BETWEEN 0 AND 2) GOTO err
	SET @errmsg = 'Non-predicted error'

	DECLARE @log_only bit
	DECLARE @warn_only bit
	IF (@ErrLevel = 1) SET @log_only = 0
	IF (@ErrLevel = 2) BEGIN 
			SET @warn_only = 0
			SET @log_only = 0
	END

	IF (@DateTime IS NULL) BEGIN
		SET @Year	 	= isNull(@Year, datePart(yyyy, getDate()))
		SET @Month 		= isNull(@Month, datePart(mm, getDate()))
		SET @Day 		= isNull(@Day, datePart(dd, getDate()))
		SET @Hour 		= isNull(@Hour, datePart(hh, getDate()))
		SET @Minute 	= isNull(@Minute, datePart(n, getDate()))
		SET @DateTime = convert(datetime, 0)
		SET @DateTime = DATEADD(yyyy, @Year - datePart(yyyy, convert(datetime, 0)), @DateTime)
		SET @DateTime = DATEADD(mm, @Month - datePart(mm, convert(datetime, 0)), @DateTime)
		SET @DateTime = DATEADD(dd, @Day - datePart(mm, convert(datetime, 0)), @DateTime)
		SET @DateTime = DATEADD(hh, @Hour, @DateTime)
		SET @DateTime = DATEADD(n, @Minute, @DateTime)
	END
	IF (@dbg = 1) BEGIN 
		SELECT '@DateTime = ' + convert(varchar(255), @DateTime) AS DateTime,
				'@MinutesAgo = ' + convert(varchar(255), @MinutesAgo) AS MinutesAgo,
				'@AgentName = ' + convert(varchar(255), @AgentName) AS AgentName,
				'@Statement = ' + convert(varchar(255), @Statement) AS Statement,
				'@LogDesc = ' + convert(varchar(255), @LogDesc) AS LogDesc,
				'@log_only = ' + convert(varchar(255), @log_only) AS log_only,
				'@warn_only = ' + convert(varchar(255), @warn_only) AS warn_only
	END
	SELECT * FROM SQL_ERR_LOG
	WHERE DateTime > dateAdd(n, @MinutesAgo * -1, @DateTime) 
		AND DateTime 	< 		@DateTime 
		AND AgentName 	LIKE 	isNull(@AgentName, isNull(AgentName, ''))
		AND Statement 	LIKE 	isNull(@Statement, Statement)
		AND isNull(LogDesc, '') 	LIKE 	isNull(@LogDesc, isNull(LogDesc, ''))
		AND IsLogOnly 	= 		isNull(@log_only, IsLogOnly)
		AND IsWarnOnly 	= 		isNull(@warn_only, IsWarnOnly)
	RETURN 0
err:
	raisError(@errmsg, 16, 1)
	RETURN -1
END
GO

