

SELECT DISTINCT 
	DB_NAME(dovs.database_id)						AS DBName,
	dovs.logical_volume_name						AS LogicalName,	
	dovs.volume_mount_point							AS Drive,
	CONVERT(INT,dovs.available_bytes / 1048576.0)	AS FreeSpaceInMB
FROM sys.master_files AS mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) AS dovs
ORDER BY DBName, FreeSpaceInMB ASC
GO