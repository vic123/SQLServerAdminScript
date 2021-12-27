SET QUOTED_IDENTIFIER OFF
go
IF OBJECT_ID('ProcessFileDetailes_ListZip_7Zip') IS NOT NULL  
  DROP PROC ProcessFileDetailes_ListZip_7Zip
GO
CREATE PROC ProcessFileDetailes_ListZip_7Zip 	--   SET QUOTED_IDENTIFIER OFF
						@Dir nvarchar(4000), --with ending "\"
						@FileName nvarchar(4000),
						@TempZipPath  nvarchar(4000) = NULL
/*
Lists @FileName contents into #FileDetail


*/
/*
Pseudocode:
1. @real_zip_path = @Dir + @FileName
2. @master_zip_id = NULL
2. CURSOR over ziplist
2.1. Parse
2.2. INSERT INTO #FileDetail
2.3. INSERT INTO #FileDetail
2.4. INSERT INTO #ZippedFile (id, MasterZipId) VALUES(SCOPE_IDENTITY(), @master_zip_id)
3. @zipped_zip_id = NULL
4. @zipped_zip_path = path inside zip file, @zipped_zip_id = MasterZipId
	of bottom-most file in #FileDetail that was not yet unzipped 

*/

AS BEGIN

SET QUOTED_IDENTIFIER ON
	--err handling vars
	DECLARE @proc_name sysname, @db_name sysname    			--used for unified calling of ADM_WRITE_SQL_ERR_LOG
	SELECT @proc_name = name, @db_name = db_Name() 
		FROM sysobjects WHERE id = @@PROCID
	DECLARE @err int, @rcnt int			--"global" vars for ADM_WRITE_SQL_ERR_LOG
	DECLARE @log_desc nvarchar(4000)			-- ----""------
	DECLARE @stmnt_lastexec nvarchar(255)		-- ----""------
	DECLARE @hr_obj int				-- var for OAGetErrorInfo
	DECLARE @hr int

	--recognized archive extensions
	CREATE TABLE #ZipFileMask (pattern nvarchar(10))
	INSERT INTO #ZipFileMask VALUES ('%.zip')
	INSERT INTO #ZipFileMask VALUES ('%.rar')

	--declare custom zip-related attributes constants
	DECLARE @ZIP_ATTRIB int, @ZIPPED_ATTRIB int
	SELECT @ZIP_ATTRIB = 256, @ZIPPED_ATTRIB = 512

	--return if file is not a zip archive 
	IF NOT EXISTS (SELECT * FROM #ZipFileMask WHERE @FileName LIKE pattern) RETURN 0

	--log input params
	SET @log_desc = '@Dir nvarchar(4000) = ' + isNull('''' + @Dir + '''', 'NULL') + CHAR(10)
			+ '@FileName nvarchar(4000) = ' + isNull('''' + @FileName + '''', 'NULL') + CHAR(9) + CHAR(10) 
			+ '@TempZipPath nvarchar(4000) = ' + isNull('''' + @TempZipPath + '''', 'NULL')
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name,
					@AgentName = @proc_name,
					@Statement = '/**** Input parameters ****/',
					@RecordCount = @rcnt,
					@LogDesc = 	@log_desc,
					@UserId = NULL,
					@IsLogOnly = 1
	SET @log_desc = ''

	--add custom ZIP file attribute
	SELECT @stmnt_lastexec = "UPDATE det SET Attributes = Attributes | @ZIP_ATTRIB..."
	UPDATE det SET Attributes = Attributes | @ZIP_ATTRIB
		FROM #FileDetail det JOIN #FilePath path ON det.FilePathId = path.id
				JOIN #FileDir dir ON path.FileDirId = dir.id
		WHERE dir.dir = @Dir and path.FileName = @FileName
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) OR (@rcnt <> 1) GOTO Err
	
	--set phyzical zip archive path 
	SELECT @TempZipPath = isNull(@TempZipPath, @Dir + @FileName)

	--prepare attributes conversion table from string 'DRHSA' to integer flag
	CREATE TABLE #ZipAttribMap (
		ZipAttribPattern	char(5),
		DosAttrib		int
	)
	INSERT INTO #ZipAttribMap VALUES ('D____', 16)
	INSERT INTO #ZipAttribMap VALUES ('_R___', 1)
	INSERT INTO #ZipAttribMap VALUES ('__H__', 2)
	INSERT INTO #ZipAttribMap VALUES ('___S_', 4)
	INSERT INTO #ZipAttribMap VALUES ('____A', 32)

	--create and fill table with textual zip list output
	CREATE TABLE #ZipList (
		id int IDENTITY,
		nstr nvarchar(4000)
	)
	DECLARE @cmd nvarchar(4000)
	--	SELECT @cmd = '""D:\Program Files\7-Zip\7z.exe"" l -slt -r W:\Backup\test\_Btr2.zip  2>&1'
	--	SELECT @cmd = 'D:\"Program Files"\7-Zip\7z.exe l -slt -r W:\Backup\test\_Btr2.zip  2>&1'
	--	SELECT @cmd = '"D:\Program Files\7-Zip\7z.exe" l -slt -r W:\Backup\test\_Btr2.zip  2>&1'
	--	SELECT @cmd = '"D:\Program Files\7-Zip\7z.exe" l -slt -r W:\Backup\test\_Btr2.zip  2>&1'
	--	SELECT @cmd = '"D:\Program Files\7-Zip\7z.exe" l  -r W:\Backup\test\_Btr2.zip  2>&1'
	SELECT @cmd = '""%ProgramFiles%\7-Zip\7z.exe" l  -r "' + @TempZipPath + '" 2>&1"'
--SELECT @cmd 
	SELECT @stmnt_lastexec = "INSERT INTO #ZipList (nstr)....",
		@log_desc = @cmd, 
		@err = NULL
	INSERT INTO #ZipList (nstr)
		EXEC @err = master.dbo.xp_cmdshell @cmd
	SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
--PRINT @err
	IF (@err <> 0) BEGIN
		SELECT @log_desc = @log_desc + CHAR(10) + nstr FROM #ZipList ORDER BY id
		GOTO Err
	END ELSE BEGIN
		EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name,
						@AgentName = @proc_name,
						@Statement = @stmnt_lastexec,
						@RecordCount = @rcnt,
						@LogDesc = 	@log_desc,
						@UserId = NULL,
						@IsLogOnly = 1
		SET @log_desc = ''
	END

	DELETE FROM #ZipList WHERE nstr IS NULL


	--cursor and parse textual zip list output
--SELECT * FROM #ZipList
	DECLARE #ZipList_cur	CURSOR FOR SELECT id, nstr FROM #ZipList ORDER BY id
	DECLARE @nstr nvarchar(4000), @parse_flags int, @id int, @do_fetch bit
	SELECT @parse_flags = 0, @do_fetch = 1	
	DECLARE @HEADER_PARSED_FLAG int		--determines if we already parsed output header or not
	SET @HEADER_PARSED_FLAG = 0x1
		--, @ARCHIVE_PARSED_FLAG int, @TABLE_PARSED_FLAG int, @COLCOUNT_PARSED_FLAG int
	DECLARE 	@path_in_zip nvarchar(4000), 
			@size_c varchar(100), @size_i bigint,
			@modified_c varchar(100), @modified_dt datetime, 
			@attrib_c CHAR(5), @attrib_i int
	OPEN #ZipList_cur
	WHILE (1=1) BEGIN 
		--we may have fetched a row already expecting that it may continued line of output
		-- 	(WHEN len(@nstr) was = 255)
		SELECT 	@stmnt_lastexec = ''
		IF @do_fetch = 1 FETCH NEXT FROM #ZipList_cur INTO @id, @nstr
--SELECT @id, @nstr
		IF (@@FETCH_STATUS <> 0) BREAK
		SET @do_fetch = 1
		IF (@parse_flags & @HEADER_PARSED_FLAG) = 0  BEGIN
			--check that there is really expected 7zip header in output 
			SELECT 	@stmnt_lastexec = "IF patIndex('7-Zip %', @nstr) <> 1 GOTO Err_ZipList",
				@log_desc = @nstr
			IF patIndex('7-Zip %', @nstr) <> 1 GOTO Err_ZipList
			FETCH NEXT FROM #ZipList_cur INTO @id, @nstr
		DECLARE @list_arch_row nvarchar(4000)
		SELECT @list_arch_row = @nstr
		WHILE  len(@nstr) = 255 BEGIN
			--when file path continues on next row(s) - fetch next and see if it is the case
			SET @do_fetch = 0
			FETCH NEXT FROM #ZipList_cur INTO @id, @nstr
			IF (@@FETCH_STATUS <> 0) BREAK
			IF patIndex('   Date      Time    Attr         Size   Compressed  Name%', @nstr) = 1 BREAK
			SELECT @list_arch_row = @list_arch_row + @nstr
			SET @do_fetch = 1
		END

			SELECT 	@stmnt_lastexec = "IF patIndex('Listing archive: %', @nstr) <> 1 GOTO Err_ZipList",
				@log_desc = @nstr 
			IF patIndex('Listing archive: %', @list_arch_row) <> 1 GOTO Err_ZipList
--				SET @zip_path = rTrim(lTrim(right(@nstr, len(@nstr) - len('Listing archive: ')))
		IF @do_fetch = 1 FETCH NEXT FROM #ZipList_cur INTO @id, @nstr
		SET @do_fetch = 1
			SELECT 	@stmnt_lastexec = "IF patIndex('   Date      Time    Attr         Size   Compressed  Name%', @nstr) <> 1 GOTO Err_ZipList",
				@log_desc = @nstr
			IF patIndex('   Date      Time    Attr         Size   Compressed  Name%', @nstr) <> 1 GOTO Err_ZipList
			FETCH NEXT FROM #ZipList_cur INTO @id, @nstr
			SELECT 	@stmnt_lastexec = "IF patIndex('------------------- ----- ------------ ------------  ------------%', @nstr) <> 1 GOTO Err_ZipList",
				@log_desc = @nstr
			IF patIndex('------------------- ----- ------------ ------------  ------------%', @nstr) <> 1 GOTO Err_ZipList
			SET @parse_flags = @parse_flags | @HEADER_PARSED_FLAG
			CONTINUE 
		END

		--stop processing	
		IF patIndex('------------------- ----- ------------ ------------  ------------%', @nstr) = 1 BREAK
		--parse values from fixed positions, check that they are of correct datatype
		SELECT @modified_c = left(@nstr, 19)
		SELECT 	@stmnt_lastexec = "IF (isDate(@modified_c) <> 1) GOTO Err_ZipList",
			@log_desc = @nstr
		IF (isDate(@modified_c) <> 1) GOTO Err_ZipList
		SELECT @modified_dt = convert(varchar(100), @modified_c, 120)

		SELECT @attrib_c = substring(@nstr, 21, 5)
		SELECT @attrib_i = NULL --fix from 070103 - directories inside zip files
		SELECT @attrib_i = isNull(@attrib_i, 0) | DosAttrib
			FROM #ZipAttribMap WHERE @attrib_c LIKE ZipAttribPattern
		SELECT @attrib_i = isNull(@attrib_i, 128)

		SELECT @size_c = substring(@nstr, 26, 13)
		SELECT 	@stmnt_lastexec = "IF isNumeric(@size_c) <> 1 GOTO Err_ZipList",
			@log_desc = @nstr
		IF isNumeric(@size_c) <> 1 GOTO Err_ZipList
		SELECT @size_i = convert(bigint, @size_c)

		SELECT @path_in_zip = substring(@nstr, 54, len(@nstr))
		WHILE  len(@nstr) = 255 BEGIN	
			--when file path continues on next row(s) - fetch next and see if it is the case
			SET @do_fetch = 0
			FETCH NEXT FROM #ZipList_cur INTO @id, @nstr
			IF (@@FETCH_STATUS <> 0) BREAK
			SELECT @modified_c = left(@nstr, 19)
			--when next row starts with a string that may be a date, then we assume that it is a new list entry
			IF (isDate(@modified_c) = 1) BREAK
			SELECT @path_in_zip = @path_in_zip + @nstr
			SET @do_fetch = 1
		END

		--extract zipped folder and file name from zipped path
		DECLARE @ci_start int,
			@zipped_filedir nvarchar(4000), @zipped_filename nvarchar(4000),
			@filedetail_id int, @filedir_id int, @filepath_id int
		SELECT @ci_start = 1
		WHILE (CHARINDEX ('\', @path_in_zip, @ci_start) <> 0) BEGIN
			SET @ci_start = CHARINDEX ('\', @path_in_zip, @ci_start) + 1
		END
		--zipped folder is prepended with full qualified path of zip file 
		SELECT 	@zipped_filedir = @Dir + @FileName + '\' + left(@path_in_zip, @ci_start-1), 
			@zipped_filename = right(@path_in_zip, len(@path_in_zip) - @ci_start + 1)
			
		--insert new record in #FileDetail
		INSERT INTO #FileDetail	(AlternateName, Size, 
					CreationDate, CreationTime,
					LastWrittenDate, LastWrittenTime,
					LastAccessedDate, LastAccessedTime,
					Attributes
				)
		VALUES 	(	NULL, @size_i, 
				dbo.DT2IntDate(@modified_dt), dbo.DT2IntTime(@modified_dt),
				dbo.DT2IntDate(@modified_dt), dbo.DT2IntTime(@modified_dt),
				dbo.DT2IntDate(@modified_dt), dbo.DT2IntTime(@modified_dt),
				@attrib_i | @ZIPPED_ATTRIB
			)
		SET @filedetail_id = SCOPE_IDENTITY()

		--get filedir or create a new directory record
		SET @filedir_id = NULL
		SELECT @filedir_id = id FROM #FileDir WHERE dir = @zipped_filedir
		IF @filedir_id IS NULL BEGIN 
			SELECT 	@stmnt_lastexec = "INSERT INTO #FileDir (dir) VALUES (@file_dir)...."
			INSERT INTO #FileDir (dir) SELECT @zipped_filedir
			SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
			IF (@err <> 0 OR @rcnt <> 1) GOTO Err_ZipList
			SET  @filedir_id = SCOPE_IDENTITY()
		END
		
		--create a new path record
		SELECT 	@stmnt_lastexec = "INSERT INTO #FilePath (filedirid, filename) (@filedir_id, @file_name)"
		INSERT INTO #FilePath (filedirid, filename) VALUES (@filedir_id, @zipped_filename)
		IF (@err <> 0 OR @rcnt <> 1) GOTO Err_ZipList
		SET  @filepath_id = SCOPE_IDENTITY()
			
		--update #FileDetail with new path record id
		SELECT 	@stmnt_lastexec = "UPDATE #FileDetail SET Dir = @Dir, FileName = @file_name ..."
		UPDATE #FileDetail SET filepathid = @filepath_id
			WHERE id = @filedetail_id
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0 OR @rcnt <> 1) GOTO Err_ZipList
	END --#ZipList_cur
	CLOSE #ZipList_cur
	DEALLOCATE #ZipList_cur
	--textual output is parsed and placed in #FileDetail

	RETURN 0

Err_ZipList:
	CLOSE #ZipList_cur
	DEALLOCATE #ZipList_cur
Err:
	IF @err = 0 SET @err = -1
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name, 
					@AgentName = @proc_name,
					@Statement = @stmnt_lastexec, 
					@ErrCode = @err, 
					@RecordCount = @rcnt, 
					@LogDesc = @log_desc,
					@EMNotify = NULL, 
					@UserId = NULL
	RETURN @err
END 
GO