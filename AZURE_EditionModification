/* Spreminjaš Edicijo ( Basic, Standard ... ) in Service_Objective ( Basic, S1 , ... ) */

ALTER DATABASE [Testssms] MODIFY(EDITION='Basic' , SERVICE_OBJECTIVE='Basic')  

/* Vrne Trenutno Edicijo in Service_Objective */ 

SELECT * FROM sys.database_service_objectives

/* Vrne zgodovino sprememn in status izvedbe */

SELECT * FROM sys.dm_operation_status   
   WHERE major_resource_id = 'Testssms'   
   ORDER BY start_time DESC; 
