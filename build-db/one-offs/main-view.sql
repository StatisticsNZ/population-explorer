/*
Define a simple view that combines the various dimensions with the facts.

This is just the simplest possible view.  It's not clear that this will be necessary, as the 
Shiny app so far just draws on the wide view.  But it will be good to have this one as well, space-
permitting (views don't take up space themselves, but the indexes on them do).


Indexing is slowish - 30 minutes or more - but the result is pretty satisfactory.
2.5 hours plus (ie unfinished) on 30 October 2017

We only need this view for pop_exp, not pop_exp_dev, so pop_exp is hard coded into it
(unlike eg 74-wide-view.sql which is created for both versions)

Have taken this out of the main production because it's not clear whehter we want it or not.
Indexing this view effectively means we are using the disk space we need twice.

Peter Ellis 26 September 2017

*/

use IDI_Sandpit
IF OBJECT_ID ('pop_exp.vw_ye_mar', 'view') IS NOT NULL
DROP VIEW pop_exp.vw_ye_mar;
GO

-- schemabinding is needed so we can add indexes to it and make it a fast indexed view
CREATE VIEW pop_exp.vw_ye_mar 
WITH SCHEMABINDING
AS
SELECT
		b.snz_uid,
		year_nbr, 
		sex,
		born_nz,
		seed,
		value,
		e.short_name as value_cat,
		c.short_name as variable,
		c.variable_code,
		var_type
FROM
	pop_exp.fact_rollup_year a
INNER JOIN pop_exp.dim_person b
	ON a.fk_snz_uid = b.snz_uid
INNER JOIN pop_exp.dim_explorer_variable c
	ON a.fk_variable_code = c.variable_code
INNER JOIN pop_exp.dim_date d
	ON a.fk_date_period_ending = d.date_dt
INNER JOIN pop_exp.dim_explorer_value e
	ON a.fk_value_code = e.value_code
WHERE d.month_nbr = 3 and d.day_of_month = 31;
GO

CREATE UNIQUE CLUSTERED INDEX vw_idx_1 ON pop_exp.vw_ye_mar(snz_uid, variable_code, year_nbr); -- 33 minutes

