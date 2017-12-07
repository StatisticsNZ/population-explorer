/*
query to see which tables are being saved to what file

Peter Ellis nicked it from https://stackoverflow.com/questions/20129001/see-what-data-is-in-what-sql-server-data-file
*/

USE IDI_Sandpit
GO

select 
    OBJECT_NAME(p.object_id) as my_table_name, 
    u.type_desc,
    f.file_id,
    f.name,
    f.physical_name,
    f.size,
    f.max_size,
    f.growth,
    u.total_pages,
    u.used_pages,
    u.data_pages,
    p.partition_id,
    p.rows
from sys.allocation_units u 
    join sys.database_files f on u.data_space_id = f.data_space_id 
    join sys.partitions p on u.container_id = p.hobt_id
where 
    u.type in (1, 3) 
ORDER by physical_name


GO