/*
Writes indexes on the main fact table.

We do this last because otherwise it takes too long to write everything to disk while we're making the database, if it's writing
data to tables with indexes and constraints on them.  

Generally, don't do this to the pop_exp_dev schema, only to the version on pop_exp_dev.

The indexing takes a while anyway.  

about 50 minutes in total on 27 September, when the main fact tab le is about half a billion rows.

There is automatically a clustered index on the primary key, which is an integer for each combination of person, variable and time period.
I have an integer instead of the complex of the three variables because it should be narrower and take up less space.

Not surew we should be doing all this after all.  Depends on use cases.  The Foreign key constraints are important but the indexes
may not be necessary if people are just going to use the main "view".

Peter Ellis, September 2017
*/


/*****************************************************************************
ANNUAL VERSION
*/

-----------------Indexes--------------------------------------
 ALTER TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_year ADD PRIMARY KEY (fk_snz_uid, fk_date_period_ending, fk_variable_code);

CREATE NONCLUSTERED INDEX n_val_var ON IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_value_code, fk_variable_code)

EXECUTE IDI_Sandpit.lib.add_cs_ind 'pop_exp_dev', 'fact_rollup_year'


--------------------Foreign key constraints-----------------------
-- Foreign keys sometimes help the query optimising, and they are a good referential check
-- If any of these don't work it means that something has definitely gone wrong.  For example,
-- might have some snz_uid people who aren't on the spine.
-- These should only take a few minutes.  The snz_uid one is the longest because it has the most values to check.

ALTER TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_year
	ADD CONSTRAINT fk1_y 
	FOREIGN KEY (fk_date_period_ending) REFERENCES IDI_Sandpit.pop_exp_dev.dim_date(date_dt);

ALTER TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_year
	ADD  CONSTRAINT fk2_y
	FOREIGN KEY (fk_variable_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_variable(variable_code);

ALTER TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_year
	ADD  CONSTRAINT fk3_y 
	FOREIGN KEY (fk_value_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value_year(value_code);

ALTER TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_year
	ADD  CONSTRAINT fk4_y
	FOREIGN KEY (fk_snz_uid) REFERENCES IDI_Sandpit.pop_exp_dev.dim_person(snz_uid);

/*
--sample code for trouble shooting eg if fk4 doesn't work, how to find the variables with bad snz_uid:
SELECT * FROM
	(SELECT distinct(fk_variable_code)
	FROM idi_sandpit.pop_exp_sample.fact_rollup_year AS a
	LEFT JOIN idi_sandpit.pop_exp_sample.dim_person AS b
	ON a.fk_snz_uid = b.snz_uid
	WHERE b.snz_uid is null) as c
LEFT JOIN idi_sandpit.pop_exp_sample.dim_explorer_variable AS D
ON c.fk_variable_code = d.variable_code

select * from IDI_Sandpit.pop_exp_dev.dim_explorer_variable
*/



