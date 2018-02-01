/*
This script sets up the core tables in pop_exp_synth to receive the synthetic version of the Population Explorer data

Peter Ellis 7 December 2012
*/


IF OBJECT_ID('IDI_Sandpit.pop_exp_synth.fact_rollup_year') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_synth.fact_rollup_year
IF OBJECT_ID('IDI_Sandpit.pop_exp_synth.vw_year_wide') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_synth.vw_year_wide
GO

IF OBJECT_ID('IDI_Sandpit.pop_exp_synth.dim_explorer_value_year') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_synth.dim_explorer_value_year
GO

IF OBJECT_ID('IDI_Sandpit.pop_exp_synth.dim_explorer_variable') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_synth.dim_explorer_variable;
IF OBJECT_ID('IDI_Sandpit.pop_exp_synth.dim_person') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_synth.dim_person
IF OBJECT_ID('IDI_Sandpit.pop_exp_synth.dim_date') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_synth.dim_date
GO

USE IDI_Sandpit
IF OBJECT_ID('IDI_Sandpit.pop_exp_synth.make_empty_tables') IS NOT NULL
	DROP PROCEDURE pop_exp_synth.make_empty_tables
GO


CREATE PROCEDURE pop_exp_synth.make_empty_tables
AS
BEGIN
	SET NOCOUNT ON
	
	-- we bring the whole variable table in and we'll delete the rows we don't need later
	SELECT *
	INTO IDI_Sandpit.pop_exp_synth.dim_explorer_variable
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable 
	
	-- same with the value table:
	SELECT *
	INTO IDI_Sandpit.pop_exp_synth.dim_explorer_value_year
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_year
	
	-- For the fact table, we want an empty structure
	SELECT *
	INTO IDI_Sandpit.pop_exp_synth.fact_rollup_year
	FROM IDI_Sandpit.pop_exp_dev.fact_rollup_year
	WHERE 1 = 2

	-- same for the person table
	SELECT *
	INTO IDI_Sandpit.pop_exp_synth.dim_person
	FROM IDI_Sandpit.pop_exp_dev.dim_person
	WHERE 1 = 2

	-- We have to leave iwi in at this stage, unless we want to re-write all the code
	-- that does the pivoting later on (which explicitly includes iwi - it will get
	-- filled in with "No data" codes).
	-- ALTER TABLE IDI_Sandpit.pop_exp_synth.dim_person DROP COLUMN iwi;

	-- Bring the whole date table over as-is
	SELECT * 
	INTO IDI_Sandpit.pop_exp_synth.dim_date
	FROM IDI_Sandpit.pop_exp_dev.dim_date
END
GO

EXECUTE IDI_Sandpit.pop_exp_synth.make_empty_tables

