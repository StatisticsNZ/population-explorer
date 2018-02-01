use IDI_Sandpit

select distinct t.name, s.name
from sys.partitions p
inner join sys.tables t
on p.object_id = t.object_id
inner join sys.schemas s
on t.schema_id = s.schema_id
where p.partition_number <> 1

