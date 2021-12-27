SET QUOTED_IDENTIFIER OFF
go
IF OBJECT_ID('ProcessFileDetailes_ListZipRecursive') IS NOT NULL  
  DROP  PROC ProcessFileDetailes_ListZipRecursive
GO
CREATE PROC ProcessFileDetailes_ListZipRecursive 	@Dir nvarchar(4000), --with ending "\"
							@FileName nvarchar(4000),
							@TempDir  nvarchar(4000)

/*
Pseudocode:
@Dir - logical folder in scanned path where listed zip is located
@temp_zip_path - physical location of zip file
1. Outermost zip processing only 
1.1.
	@temp_zip_path = @Dir + @FileName, 
	@zip_dir = @Dir, 
	@zip_file_name = @FileName,
	@master_zip_id = #FileDetail.id
1.2. INSERT INTO #ZippedZip (id, TempZipPath, MasterZipId) SELECT @master_zip_id, @temp_zip_path, NULL
2. Every zip processing (WHILE 1=1)
2.1. @last_det_id = max(#FileDetail.id)
2.2. ProcessFileDetailes_ListZip_7Zip 	@Dir = @zip_dir, @FileName = @zip_file_name, @TempZipPath = @temp_zip_path
2.3. --extract zipped zips from last zip into #ZippedZip with NULL as TempZipPath
2.4. --cleanup temporary dir
2.4.1.....................
2.5. 	--get zip that is found last and that we did not process yet 
	--(i.e. we climb from the bottom of #ZippedZip list above untill meet first processed zip)
		@zip_id = NULL
		@zip_id = zz.id, 
		@zip_dir = dir.Dir,
		@zip_file_name = path.FileName,
		@zip_dir_in_zip = right(dir.Dir, len(dir.Dir) - len(master_dir.Dir + master_path.FileName + '\')),
		@master_zip_path = master_zz.TempZipPath,
		@master_zip_id = zz.MasterZipId
2.6
		--if all zips are processed then exit (cleanup??!!)
		IF (@zip_id IS NULL) BREAK
2.7
		--else define a location where zipped zip will be unzipped (tempPath\@master_zip_id) 
		SELECT @temp_zip_path = @TempDir + convert(varchar(10), @master_zip_id) + '\'
2.8 		--create folder for unzipped zips from @master_zip
2.9 		--extract zipped zip
	'"D:\Program Files\7-Zip\7z.exe" x "' + @master_zip_path + '" "' + @zip_dir_in_zip + @zip_file_name + '" -o"' + @temp_zip_path  + '" 2>&1'
2.10
	SET @temp_zip_path = @temp_zip_path + @zip_dir_in_zip + @zip_file_name 
	--save path in #ZippedZip
	UPDATE #ZippedZip SET TempZipPath = @temp_zip_path WHERE id = @zip_id
*/

/*
TEST:

--	@Dir = 'W:\RAC\SQLAdmin\ZipCopy\test\_Btr2.zip',
EXEC ProcessFiles_v2 	
	@Dir = 'W:\RAC\SQLAdmin\ZipCopy\test\',
	@FileDetailsCommand = 'EXEC @err = ProcessFileDetailes_ListZipRecursive 
					@Dir = ''{dir}'', 
					@FileName = ''{file}'', 
					@TempDir = ''W:\tmp''',
	@PostCommand =  'EXEC ProcessFilesPostCommand_StoreFileList
			SELECT * FROM ProcessFiles_FileDir dir JOIN ProcessFiles_FilePath path ON path.FileDirId = dir.id
					JOIN ProcessFiles_FileDetail det ON det.FilePathId = path.id',
	@Recurs = 1

EXEC ProcessFiles_v2 	
	@Dir = 'G:\_g\',
	@FileDetailsCommand = 'EXEC ProcessFileDetailes_ListZipRecursive 
					@Dir = ''{dir}'', 
					@FileName = ''{file}'', 
					@TempDir = ''W:\tmp''',
	@PostCommand =  'EXEC ProcessFilesPostCommand_StoreFileList',
	@Recurs = 1


EXEC ProcessFiles_v2 	
	@Dir = 'G:\_g\_bckp\_w\_ContextFolders\',
	@FileDetailsCommand = 'EXEC ProcessFileDetailes_ListZipRecursive 
					@Dir = ''{dir}'', 
					@FileName = ''{file}'', 
					@TempDir = ''W:\tmp''',
	@PostCommand =  'EXEC ProcessFilesPostCommand_StoreFileList
			SELECT * FROM ProcessFiles_FileDir dir JOIN ProcessFiles_FilePath path ON path.FileDirId = dir.id
					JOIN ProcessFiles_FileDetail det ON det.FilePathId = path.id',
	@Recurs = 1


EXEC ProcessFiles_v2 	
	@Dir = 'G:\_g\_bckp\_w\_ContextFolders\',
	@FileDetailsCommand = 'EXEC ProcessFileDetailes_ListZipRecursive 
					@Dir = ''{dir}'', 
					@FileName = ''{file}'', 
					@TempDir = ''W:\tmp''',
	@PostCommand =  'EXEC ProcessFilesPostCommand_StoreFileList
			SELECT * FROM ProcessFiles_FileDir dir JOIN ProcessFiles_FilePath path ON path.FileDirId = dir.id
					JOIN ProcessFiles_FileDetail det ON det.FilePathId = path.id',
	@Recurs = 1


--DB = 388 MB
--Folder - 200 MB 
1m23sec DB = 420 MB

sp_spaceused SQL_ERR_LOG
sp_spaceused ProcessFiles_FileDetail
sp_spaceused ProcessFiles_FilePath
sp_spaceused ProcessFiles_FileDir

EXEC ProcessFiles_v2 	
	@Dir = 'G:\_g\_bckp\_w\_vlad\',
	@FileDetailsCommand = 'EXEC @err = ProcessFileDetailes_ListZipRecursive 
					@Dir = ''{dir}'', 
					@FileName = ''{file}'', 
					@TempDir = ''W:\tmp''',
	@PostCommand =  'EXEC @err = ProcessFilesPostCommand_StoreFileList',
	@Recurs = 1
19:29
98839 files
10533 dirs




EXEC ProcessFiles_v2 	
	@Dir = 'L:\',
	@FileDetailsCommand = 'EXEC @err = ProcessFileDetailes_ListZipRecursive 
					@Dir = ''{dir}'', 
					@FileName = ''{file}'', 
					@TempDir = ''W:\tmp''',
	@ExceptFileMaskList = 'System Volume Information',
	@PostCommand =  'EXEC @err = ProcessFilesPostCommand_StoreFileList',
	@Recurs = 1

EXEC ProcessFiles_v2 	
	@Dir = 'L:\',
	@FileDetailsCommand = 'EXEC @err = ProcessFileDetailes_ListZipRecursive 
					@Dir = ''{dir}'', 
					@FileName = ''{file}'', 
					@TempDir = ''W:\tmp''',
	@PostCommand =  'EXEC @err = ProcessFilesPostCommand_StoreFileList',
	@Recurs = 1



SELECT Size, LastWrittenDate, LastWrittenTime, count(*), sum(size) 
	FROM ProcessFiles_FileDetail
	GROUP BY Size, LastWrittenDate, LastWrittenTime 
	HAVING count(*) > 1

SELECT dir.dir, path.filename, Size, LastWrittenDate, LastWrittenTime, * FROM ProcessFiles_FileDir dir 
		JOIN ProcessFiles_FilePath path ON dir.id = path.FileDirId 
	JOIN ProcessFiles_FileDetail det ON path.id = det.FilePathId
	WHERE EXISTS (SELECT Size, LastWrittenDate, LastWrittenTime 
			FROM ProcessFiles_FileDetail det1
			WHERE det1.Size = det.Size 
				AND det1.LastWrittenDate = det.LastWrittenDate
				AND det1.LastWrittenTime = det.LastWrittenTime
			GROUP BY Size, LastWrittenDate, LastWrittenTime 
			HAVING count(*) > 1
			) 
		AND Attributes & 16 = 0
	ORDER BY Size DESC, LastWrittenDate, LastWrittenTime

DROP VIEW ProcessFiles_File 
CREATE VIEW ProcessFiles_File AS 
	SELECT path.FileDirId, path.FileName, det.* 
		FROM ProcessFiles_FilePath path JOIN ProcessFiles_FileDetail det 
		ON path.id = det.FilePathId 

DROP VIEW ProcessFiles_v

CREATE VIEW ProcessFiles_v AS 
	SELECT dir.dir, f.* 
		FROM ProcessFiles_FileDir dir JOIN ProcessFiles_FileDetail f 
		ON dir.id = f.FileDirId 

SELECT * FROM ProcessFiles_v WHERE Size IS NULL


CREATE INDEX ProcessFiles_FileDir_Dir ON ProcessFiles_FileDir(Dir)
CREATE INDEX ProcessFiles_FilePath_FileDirId ON ProcessFiles_FilePath(FileDirId)
CREATE INDEX ProcessFiles_FileDetail_FilePathId ON ProcessFiles_FileDetail(FilePathId)
CREATE INDEX ProcessFiles_FileDetail_FileDirId ON ProcessFiles_FileDetail(FileDirId)
CREATE INDEX ProcessFiles_FileDetail_Size ON ProcessFiles_FileDetail(Size)

ALTER TABLE ProcessFiles_FileDetail ADD FileName nvarchar(500)
ALTER TABLE ProcessFiles_FileDetail ADD FileDirId int

CREATE INDEX ProcessFiles_FileDetail_FileName ON ProcessFiles_FileDetail(FileName)

UPDATE det SET FileDirId = path.FileDirId, FileName = path.FileName 
	FROM ProcessFiles_FilePath path JOIN ProcessFiles_FileDetail det 
		ON path.id = det.FilePathId 

SELECT * FROM ProcessFiles_FileDetail

CREATE INDEX ProcessFiles_FileDetail_LastWrittenDate ON ProcessFiles_FileDetail(Size)


SELECT dir.dir FROM ProcessFiles_FileDir dir 
		JOIN ProcessFiles_FilePath path ON dir.id = path.FileDirId 
	WHERE EXISTS (SELECT * FROM ProcessFiles_File f
			WHERE dir.id = f.FileDirId 
				AND Attributes & 16 = 0) --at least one regular file exists in th directory
	AND EXISTS(SELECT * FROM ProcessFiles_FileDir dir1
			WHERE dir.id <> dir1.id 
			AND NOT EXISTS (SELECT FileName FROM ProcessFiles_File f
					WHERE (f.FileDirId = dir.id OR f.FileDirId = dir1.id)
					GROUP BY FileName
					HAVING count(*) <> 2
					)	
		)


SELECT dir.id, dir.dir, 
	(SELECT sum(Size) FROM ProcessFiles_File f WHERE f.FileDirId = dir.id
	) AS DirSize, 
	(SELECT sum(Size) FROM ProcessFiles_FileDir dir_sum
				JOIN ProcessFiles_File f ON f.FileDirId = dir_sum.id
		WHERE dir_sum.dir LIKE dir.dir + '%' 
	) AS RecDirSize
 FROM ProcessFiles_FileDir dir 
	WHERE EXISTS (SELECT * FROM ProcessFiles_File f
			WHERE dir.id = f.FileDirId 
				AND Attributes & 16 = 0) --at least one regular file exists in th directory
	AND EXISTS(SELECT * FROM ProcessFiles_FileDir dir1
			WHERE dir.id <> dir1.id 
			AND NOT EXISTS (SELECT * FROM ProcessFiles_File f
					WHERE f.FileDirId = dir.Id
					AND NOT EXISTS (SELECT * FROM ProcessFiles_File f1
								WHERE f1.FileDirId = dir1.id
								AND f.FileName = f1.FileName
								AND f.Size = f1.Size
							)
					)	
		)
	ORDER BY   
	(SELECT sum(Size) FROM ProcessFiles_File f WHERE f.FileDirId = dir.id) DESC, 
	dir.dir, dir.id


SELECT dir.id, dir.dir, 
--	(SELECT sum(Size) FROM ProcessFiles_File f WHERE f.FileDirId = dir.id) AS DirSize, 
	dir_master.id as master_id, dir_master.dir AS master_dir 
--	(SELECT sum(Size) FROM ProcessFiles_File f WHERE f.FileDirId = dir_master.id) AS MasterDirSize 

--	(SELECT sum(Size) FROM ProcessFiles_FileDir dir_sum
--				JOIN ProcessFiles_File f ON f.FileDirId = dir_sum.id
--		WHERE dir_sum.dir LIKE dir.dir + '%' 
--	) AS RecDirSize
 FROM ProcessFiles_FileDir dir, ProcessFiles_FileDir dir_master 
	WHERE EXISTS (SELECT * FROM ProcessFiles_File f
			WHERE dir.id = f.FileDirId 
				AND Attributes & 16 = 0) --at least one regular file exists in th directory
	AND dir.id <> dir_master.id 
			AND NOT EXISTS (SELECT * FROM ProcessFiles_FileDetail f
					WHERE f.FileDirId = dir.Id
					AND NOT EXISTS (SELECT * FROM ProcessFiles_FileDetail f1
								WHERE f1.FileDirId = dir_master.id
								AND f.FileName = f1.FileName
								AND f.Size = f1.Size
							)
					)	
	ORDER BY   
--	(SELECT sum(Size) FROM ProcessFiles_File f WHERE f.FileDirId = dir.id) DESC, 
	dir.dir, dir.id



G:\_g\_bckp\_w\_ContextFolders\_webdoc\articles_non-read\NET NSE\Windows Shell Create Namespace Extensions for Windows Explorer with the _NET Framework -- MSDN Magazine, January 2004_files\premium_files\
G:\_g\_bckp\_w\_ContextFolders\_webdoc\articles_non-read\NET NSE\Windows Shell Create Namespace Extensions for Windows Explorer with the _NET Framework -- MSDN Magazine, January 2004_files\ratings_files\


	JOIN ProcessFiles_FileDetail det ON path.id = det.FilePathId
	WHERE EXISTS (SELECT Size, LastWrittenDate, LastWrittenTime 
			FROM ProcessFiles_FileDetail det1
			WHERE det1.Size = det.Size 
				AND det1.LastWrittenDate = det.LastWrittenDate
				AND det1.LastWrittenTime = det.LastWrittenTime
			GROUP BY Size, LastWrittenDate, LastWrittenTime 
			HAVING count(*) > 1
			) 
		AND Attributes & 16 = 0
	ORDER BY Size DESC, LastWrittenDate, LastWrittenTime






DECLARE @cmd nvarchar(4000), @err int
SELECT @cmd  = "EXEC @err = ProcessFileDetailes_ListZipRecursive 
					@Dir = 'G:\_g\_bckp\_w\_ContextFolders\sample\', 
					@FileName = 'The Code Project - Customizing the Windows Common File Open Dialog - Dialog and Windows.htm', 
					@TempDir = 'W:\tmp'"
EXEC sp_executesql @cmd, N'@err int OUTPUT', @err OUTPUT 
SELECT @err


EXEC ProcessFileDetailes_ListZipRecursive 
					@Dir = 'G:\_g\_bckp\_w\_ContextFolders\sample\', 
					@FileName = 'The Code Project - Customizing the Windows Common File Open Dialog - Dialog and Windows.htm', 
					@TempDir = 'W:\tmp'



DELETE ProcessFiles_FileDetail
DELETE ProcessFiles_FilePath
DELETE ProcessFiles_FileDir


SELECT TOP 100 * FROM SQL_ERR_LOG ORDER BY ErrId DESC
*/


--????@PreCommand = 'ALTER TABLE #FileDetail ADD ZipPathId....'
/*
Sample scenario
@Dir=W:\Backup\
@FileName=test\_Btr2.zip 
@TempDir=w:\tmp

@temp_zip_path=W:\RAC\SQLAdmin\ZipCopy\test\_Btr2.zip 
@FileName=test\_Btr2.zip\_Btr2\corresp\041006_BTR_{Mirror}.zip 

@TempDir=w:\tmp\ID\041006_BTR_{Mirror}.zip
@temp_zip_path=w:\tmp\ID\041006_BTR_{Mirror}.zip

@Dir=W:\Backup\
@FileName=test\_Btr2.zip\_Btr2\corresp\041006_BTR_{Mirror}.zip 

041006_BTR_{Mirror}.zip\030613.zip 
@zipped_zip_path=w:\tmp\ID\030613.zip

When zip is found, it is unziped into temp dir\ID, where ID is its 


tryout:
DROP table #t 
CREATE table #t (a int, c varchar(100) )

INSERT INTO #t VALUES (1, 'aaaa')
--DECLARE t_cur CURSOR FAST_FORWARD --FORWARD_ONLY DYNAMIC 
--DECLARE t_cur CURSOR STATIC  --FORWARD_ONLY DYNAMIC 
--DECLARE t_cur CURSOR DYNAMIC  --FORWARD_ONLY DYNAMIC 
--DECLARE t_cur CURSOR FAST_FORWARD  --FORWARD_ONLY DYNAMIC 
--DECLARE t_cur CURSOR FORWARD_ONLY 
--DECLARE t_cur CURSOR DYNAMIC FORWARD_ONLY TYPE_WARNING
DECLARE t_cur CURSOR DYNAMIC TYPE_WARNING
	FOR SELECT a FROM #t WHERE a < 1024 AND c = 'aaaa'
DECLARE @a int
OPEN t_cur
WHILE (1=1) BEGIN
	FETCH next FROM t_cur INTO @a
	IF (@@FETCH_STATUS <> 0) BREAK
	INSERT INTO #t VALUES (@a + 10, 'aaaa')
	INSERT INTO #t VALUES (@a + 10, 'bbbb')
	if @a > 10000 break
END
CLOSE t_cur
DEALLOCATE t_cur
SELECT * FROM #t
DELETE #t
Transact-SQL cursors support forward-only static, keyset-driven, and dynamic cursors.

Pseudocode:
1. @temp_zip_path = @Dir + @FileName
2. @master_zip_id = NULL
2. CURSOR over ziplist
2.1. Parse
2.2. INSERT INTO #FileDetail
2.3. INSERT INTO #FileDetail
2.4. INSERT INTO #ZippedZip (id, MasterZipId) VALUES(SCOPE_IDENTITY(), @master_zip_id)
3. @zipped_zip_id = NULL
4. @zipped_zip_path = path inside zip file, @zipped_zip_id = MasterZipId
	of bottom-most file in #FileDetail that was not yet unzipped 

When getting file details for files in #DirTree, it is logical to get details for zipped files too.
When processing outermost zip file, it gets details by standard way - by call to xp_getfiledetails in ProcessFiles
When (if) processing zipped zip, then it already has details set, and is available in #FileDetail. 
Aha - here is the reason - there is no sence in adding zipped files to #DirTree, because 
	a) we have nothing to do with any of them that are not zips
	b) we cannot access them with xp_getfiledetails






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

	--return if file is not a zip archive 
	IF NOT EXISTS (SELECT * FROM #ZipFileMask WHERE @FileName LIKE pattern) RETURN 0

	IF NOT EXISTS (SELECT * FROM #FileDetail det JOIN #FilePath path ON det.FilePathId = path.id
					JOIN #FileDir dir ON path.FileDirId = dir.id
				WHERE dir.dir = @Dir 
					AND path.FileName = @FileName 
					AND det.Attributes & 16 = 0) RETURN 0

	--log input params
	SET @log_desc = '@Dir nvarchar(4000) = ' + isNull('''' + @Dir + '''', 'NULL') + CHAR(10)
			+ '@FileName nvarchar(4000) = ' + isNull('''' + @FileName + '''', 'NULL') + CHAR(9) + CHAR(10) 
			+ '@TempDir nvarchar(4000) = ' + isNull('''' + @TempDir + '''', 'NULL')
	EXEC ADM_WRITE_SQL_ERR_LOG 	@SystemName = @db_name,
					@AgentName = @proc_name,
					@Statement = '/**** Input parameters ****/',
					@RecordCount = @rcnt,
					@LogDesc = 	@log_desc,
					@UserId = NULL,
					@IsLogOnly = 1
	SET @log_desc = ''

	IF (right(@TempDir, 1) <> '\') SET @TempDir = @TempDir + '\'
	SELECT @TempDir = isNull(@TempDir, 'c:\tmp\') + @proc_name + '\' 

	IF (right(@TempDir, 1) <> '\') SET  @TempDir = @TempDir + '\' 

	--command string and output of master.dbo.xp_cmdshell
	DECLARE @cmd nvarchar(4000)

	--create folder for unzipped zips 
	SELECT @cmd = 'IF NOT EXIST "' + @TempDir + '" mkdir "' + @TempDir + '" 2>&1'
	SELECT @stmnt_lastexec = "EXEC @err = ExecXPCmdShell....",
		@log_desc = @cmd, 
		@err = NULL
	EXEC @err = ExecXPCmdShell @cmd, @db_name, @proc_name
	SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
	IF (@err <> 0) GOTO Err
	
	--create a table that will contain zips with their temporary paths 
	CREATE TABLE #ZippedZip (id int, TempZipPath nvarchar(4000), MasterZipId int)

	DECLARE @temp_zip_path nvarchar(4000), --real path of outer zip or temporary paths of extracted internal zips
		@master_zip_id int,		--id of parent zip file
		@zip_dir nvarchar(4000),
		@zip_file_name nvarchar(4000),
		@last_det_id int
--PRINT @Dir
--PRINT @FileName
	SELECT 	@temp_zip_path = @Dir + @FileName, 
		@zip_dir = @Dir,
		@zip_file_name = @FileName

	SELECT 	@master_zip_id = det.id
		FROM #FileDetail det 	JOIN #FilePath path ON det.FilePathId = path.id
					JOIN #FileDir dir ON path.FileDirId = dir.id
		WHERE dir.dir = @Dir and path.FileName = @FileName

	INSERT INTO #ZippedZip (id, TempZipPath, MasterZipId) 
		SELECT @master_zip_id, @temp_zip_path, NULL

	WHILE (1=1) BEGIN --"recursive" listing of zip and all zips inside it 
		--save last identity to know what was listed from current zip
		SELECT @last_det_id = max(id) FROM #FileDetail det 
	
		--list zip into #FileDetail
		SELECT @stmnt_lastexec = "EXEC ProcessFileDetailes_ListZip_7Zip @Dir = @zip_dir, ....",
			@log_desc = @temp_zip_path, 
			@err = NULL
--PRINT @temp_zip_path
		EXEC @err = ProcessFileDetailes_ListZip_7Zip 	@Dir = @zip_dir, 
								@FileName = @zip_file_name, 
								@TempZipPath = @temp_zip_path
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
--ignore this error		IF (@err <> 0) GOTO Err

		--extract zipped zips from last zip into #ZippedZip
		INSERT INTO #ZippedZip (id, TempZipPath, MasterZipId) 
			SELECT det.id, NULL, @master_zip_id 
				FROM #FileDetail det 	JOIN #FilePath path ON det.FilePathId = path.id
			WHERE EXISTS (SELECT * FROM #ZipFileMask WHERE path.filename LIKE pattern) 
			AND det.id > @last_det_id
			AND det.Attributes & 16 = 0

		--cleanup temporary dir
--		DECLARE ZippedZipUnzipped_Cur CURSOR FOR 
--SELECT * FROM #ZippedZip zz 

--		DECLARE ZippedZipUnzipped_Cur CURSOR FOR 
--		OPEN ZippedZipUnzipped_Cur
		WHILE (1 = 1) BEGIN --cleanup temporary paths
			SET @master_zip_id = NULL	
			SELECT TOP 1 @master_zip_id = id
				FROM #ZippedZip zz 
					WHERE EXISTS (SELECT * FROM #ZippedZip zz1 WHERE zz1.MasterZipId = zz.id)
					AND NOT EXISTS (SELECT * FROM #ZippedZip zz1 WHERE zz1.id > zz.id AND zz1.TempZipPath IS NULL)
				ORDER BY id
			IF @master_zip_id IS NULL BREAK
			SELECT @temp_zip_path = @TempDir + convert(varchar(10), @master_zip_id) + '\'
			SELECT @cmd = 'rmdir /S /Q "' + @temp_zip_path + '" 2>&1'
			SELECT @stmnt_lastexec = "EXEC @err = ExecXPCmdShell....",
				@log_desc = @cmd, 
				@err = NULL
			EXEC @err = ExecXPCmdShell @cmd, @db_name, @proc_name
--SELECT @cmd
			SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
--ignore this error			IF (@err <> 0) GOTO Err_ZippedZipUnzipped_Cur
			DELETE #ZippedZip WHERE id = @master_zip_id
		END --cleanup temporary paths
--		CLOSE ZippedZipUnzipped_Cur
--		DEALLOCATE ZippedZipUnzipped_Cur

		--get last zip found that we did not process yet 
		DECLARE @zipped_zip_path nvarchar(4000), @zipped_zip_id int
		DECLARE @zip_id int, @zip_dir_in_zip nvarchar(4000), @master_zip_path nvarchar(4000)
		SET @zip_id = NULL
		SELECT TOP 1 	@zip_id = zz.id, 
				@zip_dir = dir.Dir,
				@zip_file_name = path.FileName,
				@zip_dir_in_zip = right(dir.Dir, len(dir.Dir) - len(master_dir.Dir + master_path.FileName + '\')),
				@master_zip_path = master_zz.TempZipPath,
				@master_zip_id = zz.MasterZipId
--				@master_path = master_dir.Dir + master_path.FileName + '\'
			FROM #ZippedZip zz JOIN #FileDetail det ON zz.id = det.id
				JOIN #FilePath path ON det.FilePathId = path.id
				JOIN #FileDir dir ON path.FileDirId = dir.id
				JOIN #ZippedZip master_zz ON zz.MasterZipId = master_zz.id
				JOIN #FileDetail master_det ON master_zz.id = master_det.id
				JOIN #FilePath master_path ON master_det.FilePathId = master_path.id
				JOIN #FileDir master_dir ON master_path.FileDirId = master_dir.id
			WHERE zz.TempZipPath IS NULL
			ORDER BY zz.id DESC

--PRINT 11111		
--SELECT  @zip_id
		--if all zips are processed then exit (cleanup??!!)
		IF (@zip_id IS NULL) BREAK
		--else define a location where zipped zip will be unzipped (tempPath\@master_zip_id) 
		SELECT @temp_zip_path = @TempDir + convert(varchar(10), @master_zip_id) + '\'

--PRINT 11112
		--create folder for unzipped zips from @master_zip
		SELECT @cmd = 'IF NOT EXIST "' + @temp_zip_path + '" mkdir "' + @temp_zip_path + '" 2>&1'
		SELECT @stmnt_lastexec = "EXEC @err = ExecXPCmdShell....",
			@log_desc = @cmd, 
			@err = NULL
		EXEC @err = ExecXPCmdShell @cmd, @db_name, @proc_name
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
--PRINT 11113
		--extract zipped zip
--PRINT @temp_zip_path  + @zip_file_name
		SELECT @cmd = '"D:\Program Files\7-Zip\7z.exe" x "' + @master_zip_path + '" "' + @zip_dir_in_zip + @zip_file_name + '" -o"' + @temp_zip_path  + '" 2>&1'
--PRINT @cmd
		SELECT @stmnt_lastexec = "EXEC @err = ExecXPCmdShell....",
			@log_desc = @cmd, 
			@err = NULL
		EXEC @err = ExecXPCmdShell @cmd, @db_name, @proc_name
		SELECT @err = coalesce(nullif(@@ERROR, 0), @err, -4711), @rcnt = @@ROWCOUNT
		IF (@err <> 0) GOTO Err
--PRINT @zip_dir_in_zip
		SELECT @temp_zip_path = @temp_zip_path + @zip_dir_in_zip + @zip_file_name,
			@master_zip_id = @zip_id
		--save path in #ZippedZip
--PRINT @temp_zip_path
		UPDATE #ZippedZip SET TempZipPath = @temp_zip_path WHERE id = @zip_id
		SELECT @err = @@ERROR, @rcnt = @@ROWCOUNT
		IF (@err <> 0 OR @rcnt <> 1) GOTO Err

	END --"recursive" listing of zip and all zips inside it 
--PRINT 11121
	RETURN 0

Err_ZippedZipUnzipped_Cur:		
	CLOSE ZippedZipUnzipped_Cur
	DEALLOCATE ZippedZipUnzipped_Cur


Err:
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