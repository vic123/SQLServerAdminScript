SET QUOTED_IDENTIFIER OFF
GO
IF OBJECT_ID('CopyTable') IS NOT NULL  
  DROP PROC CopyTable
GO

CREATE PROC CopyTable 	@DBName sysname, --SET QUOTED_IDENTIFIER OFF
			@TableName sysname, 
			@NewDBName sysname, 
			@DoDrop bit = 0,
			@DoDelete bit = 0,
			@UseExisting bit = 0,
			@DeleteExisting bit = 0,
			@DoCheckSumCheck bit = 1,
			@CopiedRows int = NULL OUTPUT,
			@CheckSum int = NULL OUTPUT
AS
BEGIN
DECLARE @LOG_TO_SQLAdmin bit 
SET @LOG_TO_SQLAdmin = 1

--declare a set of standard error logging variables
	DECLARE @proc_name sysname				--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	DECLARE @db_name sysname				-- ----""------
	SELECT 	@proc_name = name, @db_name = db_Name() FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int				--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @log_desc varchar(8000)			-- ----""------
	DECLARE @stmnt_lastexec varchar(255)	-- ----""------

--optionally log input parameters, it is a valuable info
	IF @LOG_TO_SQLAdmin = 1 BEGIN
		SELECT @proc_name = name, @db_name = db_Name() FROM sysobjects WHERE id = @@PROCID	
		SELECT @stmnt_lastexec =   'Input parameters'
		SELECT @log_desc = 	'@DBName sysname: ' + isNull('''' + @DBName + '''', 'NULL') + CHAR(10)
					+ '@TableName sysname: ' + isNull('''' + @TableName + '''', 'NULL') + CHAR(10)
					+ '@NewDBName sysname: ' + isNull('''' + @NewDBName + '''', 'NULL') + CHAR(10)
					+ '@DoDrop bit: ' + isNull(convert(varchar(100), @DoDrop), 'NULL') + CHAR(10)
					+ '@DoDelete bit: ' + isNull(convert(varchar(100), @DoDelete), 'NULL') + CHAR(10)
					+ '@UseExisting bit: ' + isNull(convert(varchar(100), @UseExisting), 'NULL') + CHAR(10)
					+ '@DeleteExisting bit: ' + isNull(convert(varchar(100), @DeleteExisting), 'NULL') + CHAR(10)

					+ '@CopiedRows int: ' + isNull(convert(varchar(100), @CopiedRows), 'NULL')
		EXEC SQLAdmin.dbo.ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
						@AgentName = @proc_name,
						@Statement = @stmnt_lastexec,
						@RecordCount = @rcnt,
						@LogDesc = 	@log_desc,
						@IsLogOnly = 1
		SELECT @log_desc =''
	END
	
	BEGIN TRAN 
		DECLARE @InitialRows int
	
		DECLARE @sql nvarchar (4000)

/*	
		SET @sql = 'USE ' + @DBName + CHAR(10)
			 + 'EXEC @err = SQLAdmin..CreateAndExecTableScript @TableName = ''' + @TableName + ''', ' + CHAR(10)
					+ '@SQLCreate = @SQLCreate OUTPUT, ' + CHAR(10)
					+ '@SQLPK = @SQLPK OUTPUT, ' + CHAR(10)
					+ '@SQLDF = @SQLDF OUTPUT, ' + CHAR(10)
					+ '@SQLIndex = @SQLIndex' + CHAR(10)
*/	
		
		DECLARE @obj_name nvarchar(1000)
		SELECT @obj_name = @NewDBName + '..' + @TableName


		IF OBJECT_ID(@obj_name, 'U') IS NOT NULL AND @UseExisting = 1 BEGIN
			DECLARE @cnt int
			SET @sql = 'SELECT @cnt = count(*) FROM ' + @obj_name
			SELECT 	@stmnt_lastexec = "EXEC @err = sp_executesql @sql", 
						@err = NULL, 
						@log_desc = @sql
			EXEC @err = sp_executesql @sql, N'@cnt int OUTPUT', @cnt OUTPUT 
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err

			IF (@cnt <> 0) BEGIN
				IF @DeleteExisting = 1 BEGIN
					SET @sql = 'DELETE * FROM ' + @obj_name
					SELECT 	@stmnt_lastexec = "EXEC @err = sp_executesql @sql", 
								@err = NULL, 
								@log_desc = @sql
					EXEC @err = sp_executesql @sql
					SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
					IF (@err <> 0) GOTO Err
					SELECT 	@log_desc = convert(varchar(20), @cnt) + 'rows were DELETED.'
				END ELSE SELECT 	@log_desc = 'Table rows were PRESERVED.'
	
				SELECT 	@stmnt_lastexec = "IF (@cnt <> 0) BEGIN...", 
						@err = NULL, 
						@log_desc = '@obj_name contains ' 
								+ convert(varchar(20), @cnt) 
								+ 'rows. '
								+ @log_desc
				EXEC SQLAdmin.dbo.ADM_WRITE_SQL_ERR_LOG @SystemName = @db_name, 
						@AgentName = @proc_name,
						@Statement = @stmnt_lastexec,
						@RecordCount = @rcnt,
						@LogDesc = 	@log_desc,
						@IsWarnOnly = 1
			END --IF (@cnt <> 0) BEGIN
		END --IF OBJECT_ID(@obj_name, 'U') IS NOT NULL AND @UseExisting = 1 BEGIN

--SELECT @obj_name = @DBName + '..' + @TableName --error test
		IF OBJECT_ID(@obj_name, 'U') IS NULL OR @UseExisting = 0 BEGIN
			DECLARE 	@SQLCreate varchar(8000), 
					@SQLPK varchar(8000), 
					@SQLDF varchar(8000), 
					@SQLIndex varchar(8000) 

			SELECT 	@stmnt_lastexec = "EXEC @err = CreateAndExecTableScript @DBName = @DBName, @TableName = @TableName,...", 
						@err = NULL, 
						@log_desc = @DBName + '.' + @TableName
			EXEC @err = CreateAndExecTableScript @DBName = @DBName, @TableName = @TableName, 
						@DisplayScript = 0,
						@SQLCreate = @SQLCreate OUTPUT, 
						@SQLPK = @SQLPK OUTPUT, 
						@SQLDF = @SQLDF OUTPUT, 
						@SQLIndex = @SQLIndex OUTPUT
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err

			SET @sql = 'USE ' + @NewDBName + CHAR(10)
					+ @SQLCreate + @SQLPK + @SQLDF + @SQLIndex
			SELECT 	@stmnt_lastexec = "EXEC @err = sp_executesql @sql", 
						@err = NULL, 
						@log_desc = @sql
			EXEC @err = sp_executesql @sql 
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err
		END

		
		SET @sql = 'SELECT @InitialRows = count(*) FROM ' + @DBName + '..' + @TableName 
		EXEC @err = sp_executesql @sql, 
				N'@InitialRows int OUTPUT', 
				@InitialRows OUTPUT
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err

	
		DECLARE @sql_fields nvarchar(4000)
		SELECT @sql = 'SELECT @sql_fields = isNull(@sql_fields + '', '', '''') + ''['' + c.name + '']'' ' + CHAR(10)
			+ 'FROM ' + @DBName + '..syscolumns c ' + CHAR(10)
			+ '	INNER JOIN ' + @DBName + '..sysobjects o ON c.id = o.id' + CHAR(10)
			+ 'WHERE o.name = ''' + @TableName + '''' + CHAR(10)

		SELECT 	@stmnt_lastexec = "EXEC @err = sp_executesql @sql, N'@sql_fields nvarchar(4000) OUTPUT', @sql_fields OUTPUT", 
						@err = NULL, 
						@log_desc = @sql
		EXEC @err = sp_executesql @sql, N'@sql_fields nvarchar(4000) OUTPUT', @sql_fields OUTPUT
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT, @CopiedRows = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
--SELECT @sql_fields
		SELECT @sql = 'INSERT INTO ' + @NewDBName + '..' + @TableName + '( ' + CHAR(10)
				+ @sql_fields + ')' + CHAR(10)
				+ '	SELECT ' + @sql_fields + CHAR(10)
				+ '	FROM  ' + @DBName + '..' + @TableName 
		SELECT @sql = isNull(@sql, '@sql passed to sp_executesql IS NULL')
		SELECT 	@stmnt_lastexec = "EXEC @err = sp_executesql @sql", 
					@err = NULL, 
					@log_desc = @sql

		EXEC @err = sp_executesql @sql 
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT, @CopiedRows = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
--SELECT @CopiedRows = @CopiedRows - 1 --debug test
		IF @InitialRows <> @CopiedRows BEGIN
			SELECT @err = -1, 
				@log_desc = 'Copied and initial counts of rows do not match. ' 
					+ 'Initial: ' +  convert(varchar(30), @InitialRows)
					+ 'Copied: '  +  convert(varchar(30), @CopiedRows)
			GOTO Err
		END ELSE BEGIN 
			IF @LOG_TO_SQLAdmin = 1 BEGIN 
				EXEC SQLAdmin.dbo.ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
								@AgentName = @proc_name,
								@Statement = @stmnt_lastexec, 
								@ErrCode = @err, 
								@RecordCount = @CopiedRows, 
								@LogDesc = @log_desc,
								@IsLogOnly = 1,
								@EMNotify = NULL, 
								@UserId = NULL
			END
		END

		IF @DoCheckSumCheck = 1 BEGIN
			DECLARE @src_check int, @dst_check int

			SET @sql = 'SELECT @src_check = CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM ' 
					+ @DBName + '..' + @TableName 
			SELECT 	@stmnt_lastexec = "EXEC @err = sp_executesql @sql, N'@src_check int OUTPUT', @src_check OUTPUT ", 
						@err = NULL, 
						@log_desc = @sql
			EXEC @err = sp_executesql @sql, N'@src_check int OUTPUT', @src_check OUTPUT 
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err

			SET @sql = 'SELECT @dst_check = CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM ' + @obj_name
			SELECT 	@stmnt_lastexec = "EXEC @err = sp_executesql @sql, N'@dst_check int OUTPUT', @dst_check OUTPUT ", 
						@err = NULL, 
						@log_desc = @sql
			EXEC @err = sp_executesql @sql, N'@dst_check int OUTPUT', @dst_check OUTPUT 
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err
			
			SELECT 	@stmnt_lastexec = "IF @src_check <> @dest_check GOTO Err" 
			IF @src_check <> @dst_check GOTO Err
			
			SET @CheckSum = @src_check
		END

		IF @DoDelete = 1 BEGIN
			SELECT @sql = 'DELETE ' + @DBName + '..' + @TableName
			SELECT 	@stmnt_lastexec = "EXEC @err = sp_executesql @sql", 
						@err = NULL, 
						@log_desc = @sql
			EXEC @err = sp_executesql @sql 
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err
		END 


		IF @DoDrop = 1 BEGIN 
			SELECT @sql = 'DROP TABLE ' + @DBName + '..' + @TableName
			SELECT 	@stmnt_lastexec = "EXEC @err = sp_executesql @sql", 
						@err = NULL, 
						@log_desc = @sql
			EXEC @err = sp_executesql @sql 
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
			IF (@err <> 0) GOTO Err
		END 
	COMMIT
	RETURN 0

	Err:
		IF @err = 0 SET @err = -123456
		IF @LOG_TO_SQLAdmin = 1 BEGIN 
			EXEC SQLAdmin.dbo.ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
							@AgentName = @proc_name,
							@Statement = @stmnt_lastexec, 
							@ErrCode = @err, 
							@RecordCount = @rcnt, 
							@LogDesc = @log_desc,
							@EMNotify = NULL, 
							@UserId = NULL
		END
	--failure end
		RETURN @err
END
GO


