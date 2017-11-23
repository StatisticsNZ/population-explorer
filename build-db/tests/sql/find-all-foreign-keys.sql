

SELECT 
	fk.name AS key_name,
	s.name  AS schema_name,
	t.name  AS table_name
FROM IDI_Sandpit.sys.foreign_keys AS fk
INNER JOIN IDI_Sandpit.sys.schemas AS s
	ON fk.schema_id = s.schema_id
INNER JOIN IDI_Sandpit.sys.tables AS t
	on t.object_id = fk.parent_object_id
WHERE s.name = 'pop_exp_test'



