--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
--------------------------------------------------------------------------------- 
use IDI_Sandpit

SELECT 
	OBJECT_NAME(ind.OBJECT_ID)				AS table_name,
	ind.name								AS index_name, 
	indexstats.index_type_desc				AS index_type,
	indexstats.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) AS indexstats
INNER JOIN sys.indexes AS ind 
	ON ind.object_id = indexstats.object_id
	AND ind.index_id = indexstats.index_id
WHERE indexstats.avg_fragmentation_in_percent > 30--You can specify the percent as you want
ORDER BY indexstats.avg_fragmentation_in_percent DESC

