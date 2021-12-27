--http://forums.databasejournal.com/showpost.php?s=c95bb1c251a1f7d78822607a2a6742ce&p=129004&postcount=6
--http://forums.databasejournal.com/showthread.php?t=44193
--mikr0s
/*
CREATE PROCEDURE xp_getfiledetails1 @FileName NVARCHAR(4000) = NULL as 
	exec xp_getfiledetails @FileName
go
exec xp_getfiledetails1 'c:\work\VladLamp\support\110510_OMNITURE_Data_IMPORT\abmdev_2011-04-17.tar.gz'
select * from sql_err_log
*/
IF OBJECT_ID('xp_getfiledetails') IS NOT NULL  
  DROP PROCEDURE  xp_getfiledetails
GO

SET QUOTED_IDENTIFIER OFF
GO
CREATE PROCEDURE xp_getfiledetails
@FileName NVARCHAR(4000) = NULL --(full path) 
AS begin
	DECLARE @proc_name sysname    			--used for unified calling of ADM_WRITE_SQL_ERR_LOG
	DECLARE @db_name sysname				-- ----""------
	DECLARE @err int, @rcnt int			--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @log_desc nvarchar(4000)			-- ----""------
	--DECLARE @logmsg nvarchar(255)			-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------
	DECLARE @hr_obj int				-- var for OAGetErrorInfo
	DECLARE @hr int								-- HRESULT


	DECLARE @fileobj INT , @fsobj INT
	DECLARE @exists INT
	--DECLARE @src VARCHAR(255), @desc VARCHAR(255)

	--log input parameters, it is a valuable info
	SELECT @proc_name = name, @db_name = db_Name() FROM sysobjects WHERE id = @@PROCID	
	SELECT @stmnt_lastexec =   'Input parameters'
	SELECT @log_desc = 	'@FileName nvarchar(4000): ' + isNull('''' + @FileName + '''', 'NULL')
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
					@AgentName = @proc_name,
					@Statement = @stmnt_lastexec,
					@RecordCount = @rcnt,
					@LogDesc = 	@log_desc,
					@IsLogOnly = 1
	SET @log_desc = ''

	--create FileSystem Object
	SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OACreate 'Scripting.FileSystemObject', @hr_obj OUT "
	EXEC @hr = sp_OACreate 'Scripting.FileSystemObject', @hr_obj OUT
	IF @hr <> 0 GOTO OAErr
	SET @fsobj = @hr_obj

	--check if specified file exists
	SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OAMethod @fsobj, 'FileExists', @exists OUT, @filename"
	EXEC @hr = sp_OAMethod @fsobj, 'FileExists', @exists OUT, @FileName
	IF @hr <> 0 GOTO OAErr
	IF @exists = 0	BEGIN
		SET @log_desc = 'The system cannot find the file specified.'
		goto Err
	END

	--Create file object that points to specified file
	SELECT 	@stmnt_lastexec = "EXEC @hr  = sp_OAMethod @fsobj, 'GetFile' , @fileobj OUTPUT, @filename"
	EXEC @hr  = sp_OAMethod @fsobj, 'GetFile' , @fileobj OUTPUT, @filename
	IF @hr <> 0 GOTO OAErr
	SET @hr_obj = @fileobj
	--Declare variables holding properties of file
	DECLARE @Attributes TINYINT,
			@DateCreated DATETIME,
			@DateLastAccessed DATETIME,
			@DateLastModified DATETIME,
			--@Drive VARCHAR(1),
			@Name NVARCHAR(255),
			--@ParentFolder NVARCHAR(255),
			--@Path NVARCHAR(255),
			--@ShortPath NVARCHAR(255),
			@Size INT
			--@Type NVARCHAR(255)

	SELECT 	@stmnt_lastexec = ''
	SET @log_desc = 'Get properties of fileobject - Attributes, DateCreated, etc.'
	--Get properties of fileobject
	SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OAGetProperty @fileobj, 'Attributes', @Attributes OUT"
	EXEC @hr = sp_OAGetProperty @fileobj, 'Attributes', @Attributes OUT
	IF @hr <> 0 GOTO OAErr
	SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OAGetProperty @fileobj, 'DateCreated', @DateCreated OUT"
	EXEC @hr = sp_OAGetProperty @fileobj, 'DateCreated', @DateCreated OUT
	IF @hr <> 0 GOTO OAErr
	SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OAGetProperty @fileobj, 'DateLastAccessed', @DateLastAccessed OUT"
	EXEC @hr = sp_OAGetProperty @fileobj, 'DateLastAccessed', @DateLastAccessed OUT
	IF @hr <> 0 GOTO OAErr
	SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OAGetProperty @fileobj, 'DateLastModified', @DateLastModified OUT"
	EXEC @hr = sp_OAGetProperty @fileobj, 'DateLastModified', @DateLastModified OUT
	IF @hr <> 0 GOTO OAErr
	/*SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OAGetProperty @fileobj, 'Drive', @Drive OUT"
	EXEC @hr = sp_OAGetProperty @fileobj, 'Drive', @Drive OUT
	IF @hr <> 0 GOTO OAErr*/
	SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OAGetProperty @fileobj, 'Name', @Name OUT"
	EXEC @hr = sp_OAGetProperty @fileobj, 'Name', @Name OUT
	IF @hr <> 0 GOTO OAErr
	/*SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OAGetProperty @fileobj, 'ParentFolder', @ParentFolder OUT"
	EXEC @hr = sp_OAGetProperty @fileobj, 'ParentFolder', @ParentFolder OUT
	IF @hr <> 0 GOTO OAErr
	SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OAGetProperty @fileobj, 'Path', @Path OUT"
	EXEC @hr = sp_OAGetProperty @fileobj, 'Path', @Path OUT
	IF @hr <> 0 GOTO OAErr
	SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OAGetProperty @fileobj, 'ShortPath', @ShortPath OUT"
	EXEC @hr = sp_OAGetProperty @fileobj, 'ShortPath', @ShortPath OUT
	IF @hr <> 0 GOTO OAErr*/
	SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OAGetProperty @fileobj, 'Size', @Size OUT"
	EXEC @hr = sp_OAGetProperty @fileobj, 'Size', @Size OUT
	IF @hr <> 0 GOTO OAErr
	/*SELECT 	@stmnt_lastexec = "EXEC @hr = sp_OAGetProperty @fileobj, 'Type', @Type OUT"
	EXEC @hr = sp_OAGetProperty @fileobj, 'Type', @Type OUT*/
	IF @hr <> 0 GOTO OAErr
	SET @log_desc = ''
	--destroy File Object
	EXEC @hr = sp_OADestroy @fileobj
	IF @hr <> 0 GOTO OAErr

	SET @hr_obj = @fsobj
	--destroy FileSystem Object
	EXEC @hr = sp_OADestroy @fsobj
	IF @hr <> 0 GOTO OAErr

	--return results
	SELECT NULL AS [Alternate Name],
	@Size AS [Size],
	CONVERT(varchar, @DateCreated, 112) AS [Creation Date],
	REPLACE(CONVERT(varchar, @DateCreated, 108), ':', '') AS [Creation Time],
	CONVERT(varchar, @DateLastModified, 112) AS [Last Written Date],
	REPLACE(CONVERT(varchar, @DateLastModified, 108), ':', '') AS [Last Written Time],
	CONVERT(varchar, @DateLastAccessed, 112) AS [Last Accessed Date],
	REPLACE(CONVERT(varchar, @DateLastAccessed, 108), ':', '') AS [Last Accessed Time],
	@Attributes AS [Attributes]

	RETURN @hr
OAErr:
	SET @log_desc  = isNull(@log_desc, '') + dbo.OAGetErrorInfo (@hr_obj, @hr) 
--	SELECT @log_desc 
	SET @err = isNull(@hr, -4711)
--error handler
Err:
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
								@AgentName = @proc_name,
								@Statement = @stmnt_lastexec, 
								@ErrCode = @err, 
								@RecordCount = @rcnt, 
								@LogDesc = @log_desc,
								@EMNotify = NULL, 
								@UserId = NULL
--failure end
	RETURN @err

end
go