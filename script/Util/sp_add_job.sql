USE msdb
GO
/*
EXEC sp_configure 'allow updates', '1'
RECONFIGURE WITH OVERRIDE
EXEC sp_configure

EXEC master.dbo.sp_MS_upd_sysobj_category 1
*/
GO


ALTER PROCEDURE sp_add_job
  @job_name                     sysname,
  @enabled                      TINYINT          = 1,        -- 0 = Disabled, 1 = Enabled
  @description                  NVARCHAR(512)    = NULL,
  @start_step_id                INT              = 1,
  @category_name                sysname          = NULL,
  @category_id                  INT              = NULL,     -- A language-independent way to specify which category to use
  @owner_login_name             sysname          = NULL,     -- The procedure assigns a default
  @notify_level_eventlog        INT              = 2,        -- 0 = Never, 1 = On Success, 2 = On Failure, 3 = Always
  @notify_level_email           INT              = 0,        -- 0 = Never, 1 = On Success, 2 = On Failure, 3 = Always
  @notify_level_netsend         INT              = 0,        -- 0 = Never, 1 = On Success, 2 = On Failure, 3 = Always
  @notify_level_page            INT              = 0,        -- 0 = Never, 1 = On Success, 2 = On Failure, 3 = Always
  @notify_email_operator_name   sysname          = NULL,
  @notify_netsend_operator_name sysname          = NULL,
  @notify_page_operator_name    sysname          = NULL,
  @delete_level                 INT              = 0,        -- 0 = Never, 1 = On Success, 2 = On Failure, 3 = Always
  @job_id                       UNIQUEIDENTIFIER = NULL OUTPUT,
  @originating_server           NVARCHAR(30)     = NULL
AS
BEGIN
  DECLARE @retval                     INT
  DECLARE @notify_email_operator_id   INT
  DECLARE @notify_netsend_operator_id INT
  DECLARE @notify_page_operator_id    INT
  DECLARE @owner_sid                  VARBINARY(85)

  SET NOCOUNT ON

  IF (@originating_server IS NULL) OR (UPPER(@originating_server) = '(LOCAL)')
    SELECT @originating_server= UPPER(CONVERT(NVARCHAR(30), SERVERPROPERTY('ServerName')))

  -- Remove any leading/trailing spaces from parameters (except @owner_login_name)
  SELECT @originating_server           = LTRIM(RTRIM(@originating_server))
  SELECT @job_name                     = LTRIM(RTRIM(@job_name))
  SELECT @description                  = LTRIM(RTRIM(@description))
  SELECT @category_name                = LTRIM(RTRIM(@category_name))
  SELECT @notify_email_operator_name   = LTRIM(RTRIM(@notify_email_operator_name))
  SELECT @notify_netsend_operator_name = LTRIM(RTRIM(@notify_netsend_operator_name))
  SELECT @notify_page_operator_name    = LTRIM(RTRIM(@notify_page_operator_name))

  -- Turn [nullable] empty string parameters into NULLs
  IF (@description                  = N'') SELECT @description                  = NULL
  IF (@category_name                = N'') SELECT @category_name                = NULL
  IF (@notify_email_operator_name   = N'') SELECT @notify_email_operator_name   = NULL
  IF (@notify_netsend_operator_name = N'') SELECT @notify_netsend_operator_name = NULL
  IF (@notify_page_operator_name    = N'') SELECT @notify_page_operator_name    = NULL

  -- Default the owner (if not supplied or if a non-sa is [illegally] trying to create a job for another user)
  IF (@owner_login_name IS NULL) OR ((ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) = 0) AND (@owner_login_name <> SUSER_SNAME()))
    SELECT @owner_sid = SUSER_SID()
  ELSE
    SELECT @owner_sid = SUSER_SID(@owner_login_name) -- If @owner_login_name is invalid then SUSER_SID() will return NULL

  -- Default the description (if not supplied)
  IF (@description IS NULL)
    SELECT @description = FORMATMESSAGE(14571)

  -- If a category ID is provided this overrides any supplied category name
  IF (@category_id IS NOT NULL)
  BEGIN
    SELECT @category_name = name
    FROM msdb.dbo.syscategories
    WHERE (category_id = @category_id)
    SELECT @category_name = ISNULL(@category_name, FORMATMESSAGE(14205))
  END

  -- Check parameters
  EXECUTE @retval = sp_verify_job NULL,  --  The job id is null since this is a new job
                                  @job_name,
                                  @enabled,
                                  @start_step_id,
                                  @category_name,
                                  @owner_sid                  OUTPUT,
                                  @notify_level_eventlog,
                                  @notify_level_email         OUTPUT,
                                  @notify_level_netsend       OUTPUT,
                                  @notify_level_page          OUTPUT,
                                  @notify_email_operator_name,
                                  @notify_netsend_operator_name,
                                  @notify_page_operator_name,
                                  @delete_level,
                                  @category_id                OUTPUT,
                                  @notify_email_operator_id   OUTPUT,
                                  @notify_netsend_operator_id OUTPUT,
                                  @notify_page_operator_id    OUTPUT,
                                  @originating_server         OUTPUT
  IF (@retval <> 0)
    RETURN(1) -- Failure

  IF (@job_id IS NULL)
  BEGIN
    -- Assign the GUID
    SELECT @job_id = NEWID()
  END
  ELSE
  BEGIN
    -- A job ID has been provided, so check that the caller is SQLServerAgent (inserting an MSX job)
    IF (PROGRAM_NAME() NOT LIKE N'SQLAgent%')
    BEGIN
      RAISERROR(14284, -1, -1)
      RETURN(1) -- Failure
    END
  END

  INSERT INTO msdb.dbo.sysjobs
         (job_id,
          originating_server,
          name,
          enabled,
          description,
          start_step_id,
          category_id,
          owner_sid,
          notify_level_eventlog,
          notify_level_email,
          notify_level_netsend,
          notify_level_page,
          notify_email_operator_id,
          notify_netsend_operator_id,
          notify_page_operator_id,
          delete_level,
          date_created,
          date_modified,
          version_number)
  VALUES (@job_id,
          @originating_server,
          @job_name,
          @enabled,
          @description,
          @start_step_id,
          @category_id,
          @owner_sid,
          @notify_level_eventlog,
          @notify_level_email,
          @notify_level_netsend,
          @notify_level_page,
          @notify_email_operator_id,
          @notify_netsend_operator_id,
          @notify_page_operator_id,
          @delete_level,
          GETDATE(),
          GETDATE(),
          1) -- Version number 1
  SELECT @retval = @@error

  -- If misc. replication job, then update global replication status table
  IF (@category_id IN (11, 12, 16, 17, 18))
  BEGIN
    -- Nothing can be done if this fails, so don't worry about the return code
    EXECUTE master.dbo.sp_MSupdate_replication_status
      @publisher = '',
      @publisher_db = '',
      @publication = '',
      @publication_type = -1,
      @agent_type = 5,
      @agent_name = @job_name,
      @status = NULL    -- Never run
  END

  -- NOTE: We don't notify SQLServerAgent to update it's cache (we'll do this in sp_add_jobserver)

  RETURN(@retval) -- 0 means success
END

GO


--EXEC master.dbo.sp_MS_upd_sysobj_category 2
GO

/*
EXEC sp_configure 'allow updates', '0'
RECONFIGURE WITH OVERRIDE
EXEC sp_configure
*/

--PRINT 'Granting EXECUTE permission'
--GRANT EXEC ON sp_add_job TO public
--DENY EXEC ON sp_add_job FROM TargetServersRole

--EXEC sp_MS_marksystemobject 'sp_add_job'
