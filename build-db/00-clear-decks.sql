/*
Drops all tables in the schema

Beware this is pretty drastic!  Takes many hours to re-create these.

The order is important because of the various foreign key constraints - have to delete the most downstream tables first.

Peter Ellis, 30 October 2017

*/

/*
-- one off tasks only needed when moving to a new server

--USE IDI_Sandpit;
--GO

create schema pop_exp;
create schema pop_exp_dev;
create schema pop_exp_test;
create schema intermediate;
create schema lib
*/

USE IDI_Sandpit;

IF object_id('idi_sandpit.pop_exp_dev.vw_ye_mar') is not null
	DROP VIEW pop_exp_dev.vw_ye_mar;


IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.vw_ye_mar_wide') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.vw_ye_mar_wide;
GO

IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.vw_year_wide') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide;
GO


IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.br_variable_tables') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.br_variable_tables;


IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.link_person_extended') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.link_person_extended;
GO

IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.fact_rollup_year') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_year;
GO

IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.fact_rollup_qtr') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.fact_rollup_qtr;
GO


IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.dim_explorer_value') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.dim_explorer_value;
GO

IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr;
GO


IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.dim_explorer_variable') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.dim_explorer_variable;
GO

IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.dim_date') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.dim_date;
GO

IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.dim_person') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.dim_person;

