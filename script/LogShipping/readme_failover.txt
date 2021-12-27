0. Kill users
1. Bring  database on standby alive with command
RESTORE DATABASE Prod WITH RECOVERY
2. Ensure that ASP SQL Sevrer login exists on standby server with identical to production one password.
3. Map ASP SQL Sevrer login to DB user name with command 
USE Prod
GO
exec sp_change_users_login  @Action =  'Update_One', @UserNamePattern = 'prod_sys' , @LoginName = 'prod_sys'
4. Activate any other necessary logins/DB users with steps simular to 2 and 3.

Note: login to DB user mapping of step 3 is valid only for logins with SQL Server authentication. It looks like that mappings for logins with NT authentication are restored automatically, either during DB restore (if appropriate login exists on standby) or at the moment of such login creation, however it was not tested thoroughly and no explicit confirmation about this fact was found in MS SQL Server documentation yet.


6. To manually activate production server back again:
shut down ASP application
perform full standby server backup
restore it on production server
remap production server logins to users in database.
copy AssessmentDocuments
