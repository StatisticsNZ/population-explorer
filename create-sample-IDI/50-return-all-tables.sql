/*
This query returns all the tables that have been created in the IDI_Sample database.
It's meant to be run as the last step and can be useful for tests etc.

There should be about 370 of them.  You can also use this to monitor the process
during creation, which can take quite a few hours.  Nice to run this query occasionally
and check that tables are indeed still being added!

Peter Ellis 15 November 2017
*/

SELECT 
	s.name,
	o.name,
	s.name + '.' + o.name AS full_name, 
	o.type_desc, 
	o.create_date
FROM IDI_Sample.sys.objects o
INNER JOIN 	IDI_Sample.sys.schemas AS s
	ON o.schema_id = s.schema_id
WHERE o.type_desc = 'USER_TABLE'
ORDER BY create_date DESC

