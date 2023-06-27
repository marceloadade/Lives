------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
--on primary:

CREATE ENDPOINT endpoint_mirroring  
    STATE = STARTED  
    AS TCP ( LISTENER_PORT = 5022 )  
    FOR DATABASE_MIRRORING (ROLE = ALL);
GO  

CREATE AVAILABILITY GROUP [FestivalAG]
WITH (AUTOMATED_BACKUP_PREFERENCE = SECONDARY,
DB_FAILOVER = ON,
DTC_SUPPORT = NONE,
REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT = 0,
CONTAINED, REUSE_SYSTEM_DATABASES)
FOR 
REPLICA ON N'Lab01' WITH (ENDPOINT_URL = N'TCP://Lab01.edge.ad.com:5022', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, SESSION_TIMEOUT = 10, BACKUP_PRIORITY = 50, SEEDING_MODE = AUTOMATIC, PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL), SECONDARY_ROLE(ALLOW_CONNECTIONS = ALL)),
	N'Lab02' WITH (ENDPOINT_URL = N'TCP://Lab02.edge.ad.com:5022', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, SESSION_TIMEOUT = 10, BACKUP_PRIORITY = 50, SEEDING_MODE = AUTOMATIC, PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL), SECONDARY_ROLE(ALLOW_CONNECTIONS = NO));
GO

create login [edge\LAB02$] from windows;

grant connect on endpoint::[endpoint_mirroring] to [edge\LAB02$]

sp_readerrorlog

create database Pombo

backup database Pombo to disk='nul'

use Pombo
go

CREATE TABLE Initial_test
(id INT IDENTITY(1,1) NOT NULL PRIMARY KEY
,name_test VARCHAR(50) NOT null
,desc_test VARCHAR(500) NOT NULL
,guid_for_test UNIQUEIDENTIFIER
,insert_date DATETIME2 NOT NULL
)

--create data
--create job
--adding data:
--select * into [dbo].[Initial_test] from bkpPomboNaoApagar.dbo.Initial_Test_bkp
INSERT INTO [dbo].[Initial_test]
           ([name_test]
           ,[desc_test]
           ,[guid_for_test]
           ,[insert_date])
    select 
           name_test
           ,desc_test
           ,guid_for_test
           ,insert_date
	from bkpPomboNaoApagar.dbo.Initial_Test_bkp
GO




--add bd to AG
use master
go
alter availability group [FestivalAG] add database Pombo 

--test it

--create the listener:
USE [master]
GO
ALTER AVAILABILITY GROUP [FestivalAG]
ADD LISTENER N'FestivalAG_List' (
WITH IP
((N'192.168.91.52', N'255.255.255.0')
)
, PORT=1433);
GO

--connect via the listener
--notice where the master, msdb are?
--where is the AG folder?
select rcs.replica_server_name,ars.role_desc
from 
sys.dm_hadr_availability_replica_states ars join
sys.dm_hadr_availability_replica_cluster_states rcs on ars.group_id = rcs.group_id and ars.replica_id = rcs.replica_id

-- goto create the login downwards


------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
--on secondary:
CREATE ENDPOINT endpoint_mirroring  
    STATE = STARTED  
    AS TCP ( LISTENER_PORT = 5022 )  
    FOR DATABASE_MIRRORING (ROLE = ALL);
GO  


ALTER AVAILABILITY GROUP [FestivalAG] join;
ALTER AVAILABILITY GROUP [FestivalAG] grant create any database;


create login [edge\LAB01$] from windows;

grant connect on endpoint::[endpoint_mirroring] to [edge\LAB01$]


------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
--Logins and jobs:
--connect via listener

create login usrpombo with password='P@$$w0rd'

create user [usrpombo] from login usrpombo
--drop user [usrpombo]
alter role db_owner add member usrpombo
use master
grant VIEW SERVER PERFORMANCE STATE to usrpombo
go

use msdb

create user [usrpombo] from login usrpombo

alter role SQLAgentUserRole add member usrpombo
alter role SQLAgentOperatorRole add member usrpombo

--create the job
USE [msdb]
GO

/****** Object:  Job [poll_pombo]    Script Date: 9/17/2022 4:37:28 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 9/17/2022 4:37:28 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'poll_pombo', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [1]    Script Date: 9/17/2022 4:37:28 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'select * from initial_test where 1=2', 
		@database_name=N'Pombo', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

--connect to the listener using usrpombo and test
--check outside that context



--questions: now we have jobs out of context?
--question: what is wrong with that cluster


