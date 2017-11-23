/*
This script creates a table where each row represents a table in the IDI, and columns
indicate how much of each original IDI table's data is successfully linked to the spine.

There is a row for every table in the IDI that has a column named snz_uid.

The purpose is to get a slightly more finely grained view of linkage success rates than
in the data quality report that comes with the IDI refresh process.

Takes about 70 minutes to run on all 293 tables

9 November 2017, Peter Ellis
*/

EXECUTE IDI_Sandpit.lib.get_linkage_rates;

ALTER  TABLE IDI_Sandpit.intermediate.dim_idi_tables
	ADD PRIMARY KEY(table_code)
