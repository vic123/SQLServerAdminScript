IF OBJECT_ID('ProcessFilesPostCommand_StoreFileList') IS NOT NULL  
  DROP PROC ProcessFilesPostCommand_StoreFileList
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE PROC ProcessFilesPostCommand_StoreFileList AS 
--SET QOUTED IDENTIFIER OFF

--EXEC ProcessFilesPostCommand_StoreFileList
--	@PostCommand =  'SELECT * FROM #FileDir dir JOIN #FilePath path ON path.FileDirId = dir.id
--					JOIN #FileDetail det ON det.FilePathId = path.id',

BEGIN
	DECLARE @proc_name sysname				--used for unified calling of ADM_WRITE_SQL_ERR_LOG 
	DECLARE @db_name sysname				-- ----""------
	SELECT 	@proc_name = name, @db_name = db_Name() FROM sysobjects WHERE id = @@PROCID
			
	DECLARE @err int, @rcnt int				--"global" vars for ADM_WRITE_SQL_ERR_LOG
	SELECT @err = 0, @rcnt = 0
	DECLARE @log_desc varchar(8000)			-- ----""------
	DECLARE @stmnt_lastexec varchar(255)	-- ----""------

	IF NOT EXISTS (SELECT * FROM dbo.sysobjects 
				WHERE id = object_id(N'[dbo].[ProcessFiles_FileDir]') 
				AND OBJECTPROPERTY(id, N'IsUserTable') = 1) BEGIN
--DROP TABLE FileDir
		SELECT @stmnt_lastexec = "CREATE TABLE ProcessFiles_FileDir ("
		CREATE TABLE ProcessFiles_FileDir (
			id int PRIMARY KEY,
			dir nvarchar(3000),
			dt datetime DEFAULT getDate()
		)
		--CREATE UNIQUE INDEX #FileDir_dir ON #FileDir (dir ASC)
		--DROP TABLE ProcessFiles_FileDir
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
	END
	IF NOT EXISTS (SELECT * FROM dbo.sysobjects 
				WHERE id = object_id(N'[dbo].[ProcessFiles_FilePath]') 
				AND OBJECTPROPERTY(id, N'IsUserTable') = 1) BEGIN
		SELECT @stmnt_lastexec = "CREATE TABLE ProcessFiles_FilePath ("
		CREATE TABLE ProcessFiles_FilePath (
			id int PRIMARY KEY,
			FileDirId int 
				FOREIGN KEY REFERENCES ProcessFiles_FileDir(id)
			                ON DELETE CASCADE,
			FileName nvarchar(4000),
			dt datetime DEFAULT getDate()
		)
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
		--CREATE UNIQUE INDEX #FilePath_FileDirIdFileName ON #FilePath (FileDirId ASC, FileName ASC)
	END
	IF NOT EXISTS (SELECT * FROM dbo.sysobjects 
				WHERE id = object_id(N'[dbo].[ProcessFiles_FileDetail]') 
				AND OBJECTPROPERTY(id, N'IsUserTable') = 1) BEGIN
		--DROP TABLE ProcessFiles_FileDetail
		SELECT @stmnt_lastexec = "CREATE TABLE ProcessFiles_FileDetail ("
		CREATE TABLE ProcessFiles_FileDetail (
			id int PRIMARY KEY,
			FilePathId int
 				FOREIGN KEY REFERENCES ProcessFiles_FilePath(id)
			                ON DELETE CASCADE,
			AlternateName varchar(32),
			Size bigint,
			CreationDate int,
			CreationTime int,
			LastWrittenDate int,
			LastWrittenTime int,
			LastAccessedDate int,
			LastAccessedTime int,
			Attributes int,
			ProcessFlag int,
			dt datetime DEFAULT getDate()		
		)
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
	END

	DECLARE @max_dir_id int, @max_path_id int, @max_detail_id int
	SELECT @max_dir_id = isNull(max(id),0) FROM ProcessFiles_FileDir
	SELECT @max_path_id = isNull(max(id),0) FROM ProcessFiles_FilePath
	SELECT @max_detail_id = isNull(max(id),0) FROM ProcessFiles_FileDetail

	SELECT @stmnt_lastexec = "INSERT INTO ProcessFiles_FileDir (id, dir)"
	INSERT INTO ProcessFiles_FileDir (id, dir)
		SELECT id + @max_dir_id, dir FROM #FileDir
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

	SELECT @stmnt_lastexec = "INSERT INTO ProcessFiles_FilePath (id, FileDirId, FileName)"
	INSERT INTO ProcessFiles_FilePath (id, FileDirId, FileName)
		SELECT id + @max_path_id, FileDirId + @max_dir_id, FileName
			FROM #FilePath
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

	SELECT @stmnt_lastexec = "INSERT INTO ProcessFiles_FileDetail (id, FilePathId, AlternateName, Size, "
	INSERT INTO ProcessFiles_FileDetail (id, FilePathId, AlternateName, Size, 
						CreationDate, CreationTime, 
						LastWrittenDate, LastWrittenTime, 
						LastAccessedDate, LastAccessedTime, 
						Attributes, ProcessFlag)
		SELECT id + @max_detail_id, FilePathId + @max_path_id, AlternateName, Size, 
						CreationDate, CreationTime, 
						LastWrittenDate, LastWrittenTime, 
						LastAccessedDate, LastAccessedTime, 
						Attributes, ProcessFlag
			FROM #FileDetail
	SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err

--success end 
	RETURN 0
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
END
GO
