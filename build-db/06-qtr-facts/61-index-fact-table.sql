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



/**************************************************************************
                        QUARTERLY VERSION
************************************************************/

----------------------------indexes------------------------
ALTER TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_qtr ADD PRIMARY KEY (fk_snz_uid, fk_date_period_ending, fk_variable_code);

CREATE NONCLUSTERED INDEX n_val_var_q ON IDI_Sandpit.pop_exp_dev.fact_rollup_qtr(fk_value_code, fk_variable_code)

EXECUTE IDI_Sandpit.lib.add_cs_ind 'pop_exp_dev', 'fact_rollup_qtr'



--------------------Foreign key constraints-----------------------

ALTER TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_qtr
	ADD CONSTRAINT fk1_q 
	FOREIGN KEY (fk_date_period_ending) REFERENCES IDI_Sandpit.pop_exp_dev.dim_date(date_dt);

ALTER TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_qtr
	ADD  CONSTRAINT fk2_q
	FOREIGN KEY (fk_variable_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_variable(variable_code);

ALTER TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_qtr
	ADD  CONSTRAINT fk3_q 
	FOREIGN KEY (fk_value_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr(value_code);

ALTER TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_qtr
	ADD  CONSTRAINT fk4_q
	FOREIGN KEY (fk_snz_uid) REFERENCES IDI_Sandpit.pop_exp_dev.dim_person(snz_uid);

