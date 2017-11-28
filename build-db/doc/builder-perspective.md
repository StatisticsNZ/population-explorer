# Population Explorer datamart - builder perspective
Peter Ellis
29 November 2017

This document outlines the approach to building the Population Explorer datamart.  It should be read in conjunction with the accompanying "Population Explorer datamart - user perspective" which outlines the datamart's structure, defines the variables in each table, etc.

## Overall approach

The datamart is built In the `IDI_Sandpit` database on the `wtstsql35` server.  The SQL scripts that build the database all refer to the `pop_exp_dev` schema in `IDI_Sandpit`, but the datamart is rarely built in that actual schema.  Instead, there are four schemas that can hold copies of the datamart:

- `pop_exp_alpha`
- `pop_exp_bravo`
- `pop_exp_charlie`
- `pop_exp_sample`

At any one moment, there may be four complete versions of the database, based on different sampled subsets of the IDI.  The hope is that performance can be acceptable with a version that has a `spine_to_sampling_ratio` of 1.  `pop_exp_sample` always has a ratio of 100.  When it comes time to promote the datamart to production, whichever version of the datamart is best is copied over to `[wprdsql36\ileed].IDI_RnD.pop_exp` which is the version for the data lab (ie the names `pop_exp_alpha`, `pop_exp_bravo` etc are only for use in the development and test environment).

There are three other relevant schemas in the database:

- `lib` holds multi-use user-defined stored procedures and functions
- `intermediate` holds tables that are not part of the main Population Explorer datamart but are useful, expensive to build, large tables that are created on the way.  Researchers have an interest in these tables irrespective of the Population Explorer and they should be made available if and when resources permit.
- `dbo` holds 
	- the build log, 
	- a lookup table of random numbers from 0 to 300 matching to all six digit numbers used in the generation of random seeds
	- occasional quasi-temporary objects such as a table of variables left to add to the wide table in the pivoting process

The datamart is built by R running a (long) sequence of SQL scripts.  R functions:

- load up each SQL script in sequence
- split it into batches based on where `GO` has been used in the script, 
- substitute the name of the schema that is to be built (eg `pop_exp_bravo`) for the `pop_exp_dev` used by the developer of the original SQL script
- send the batches to the database server via ODBC for execution
- records activity in a log on the database `dbo.pop_exp_build_log`

A master script `build-db\build.R` will build the whole datamart from scratch with a single click.  Parameters set at the top of that script indicate 

- which is to to be the target (eg `pop_exp_alpha`), 
- whether the source data is to come from the `IDI_Clean` database or the 1/100 sampled version `IDI_Sample` database
- `spine_to_sample_ratio` which further limits the data eg 10 means 1 / 10 sample of the IDI is used as the basis for `pop_exp_xxx`

The R servers have relatively stable connections to the database and can be left connected and running scripts overnight.  R is also more flexible than pure SQL for running tests and controlling workflow.  A deliberate decision has been taken to use hand-coded SQL rather than a specialist Extract-Transform-Load toolkit so:

- the scripts creating each variable are transparent and understandable to researchers
- the datamart can be maintained and enhanced by the Integrated Data team in Stats NZ with the tools to hand.

A full build of `intermediate` takes about 20 hours.  A full build of `pop_exp` with a `spine_to_sample_ratio` of 1 takes between 14 and 40 hours on top of that.

## Folder structure

The source code for the Population Explorer is nearly all SQL, with some R used for integration - running the build and test process.  

The working version of the code is [\\wprdsql35\input_IDI\Population Explorer\build-db](\\wprdsql35\input_IDI\Population Explorer\build-db).  The `Population Explorer` directory system, of which `build-db` is the sub-system holding the code that builds the database, is a checked out version of the SVN repository that lives at \\wprdsql35\input_IDI\pop-exp-svn.  There is no need to touch \\wprdsql35\input_IDI\pop-exp-svn; all work can be done in \\wprdsql35\input_IDI\Population Explorer\build-db.

The subdirectories under `build-db` have the following purposes:

| Folder | Purpose |
|--------|---------|
| 00-src | Holds source code of re-usable user-defined stored procedures and functions. |
| 01-int-tables | Holds SQL scripts that create the tables in the `intermediate` schema.   |
| 02-setup | Holds SQL scripts that delete any existing version of the database in the target schema, creates the `dim_date`, `dim_explorer_variable`, `dim_explorer_value_year`, `dim_explorer_value_qtr`, `dim_person`, `fact_rollup_year` and `fact_rollup_qtr` tables.  `dim_date` and `dim_person` are the only tables populated at this point; the others are empty or nearly empty (eg `dim_explorer_variable` is given a single row of data at this point, the "Generic" variable which is connected to "No data" in the value table, and also is used to hold information such as the `spine_to_sample_ratio` for this instance of the datamart. Primary keys and indexes are added to `dim_person`, `dim_date`, `dim_explorer_value_XXX` and `dim_explorer_variable` but not to the fact tables.  The fact tables are to be unindexed heaps during the build process for speed while inserting data.  |
| 03-year-facts | SQL scripts that populate `fact_rollup_year`, 'dim_explorer_variable` and `dim_explorer_value_year`.  One script per variable (eg Income all sources).
| 04-year-pivot | SQL scripts that add indexes to `fact_rollup_year`, columnstore indexes to `dim_explorer_value_year` (now it is finished being added to) and pivot the data into the `vw_year_wide` table that is used by the front end and is expected to be used by researchers.  Note the name of this table implies it is a view, and it originally was; but it has been materialized as a table for performance.  Indexed views cannot have columnstore indexes in SQL Server 2012, and a columnstore index is essential for this wide table to deliver any acceptable query performance. Final steps in this stage included adding foreign key constraints to the wide "view" and columnstore indexes to it and to `dim_explorer_variable` (this can only happen now because that table is added to during the pivoting process; as each variable is added to the wide table it is recorded in `dim_explorer_variable.loaded_into_wide_table` as "Loaded"; this is to make it possible to resume from where it got up to if there is a problem, as generally happens when working with the full data). |
| 06-qtr-facts | Populate `fact_rollup_qtr` and `dim_explorer_value_qtr`.  Only variables that were already added to the yearly version are added to the quarterly, so `dim_explorer_variable` doesn't change during the load of quarterly data |
| broken | scripts that aren't working |
| doc | Documentation including snapshots of database diagrams, an Excel workbook with selected columns from `dim_explorer_variable` that is built and formatted by R as part of the build process, and this document |
| one-offs | Mostly this is SQL scripts that are not essential for the build process but which contain useful utilities (eg `check-log.sql`, `find-variables-with-duplicate-values-per-person.sql`, `spare-disk-space.sql`.  This also contains an R script that created the random number table, and some R utility analysis such as `examine-timings.R` used to analyse performance based on times recorded in the log for sample queries.|
| output | Images and files from analysis (not much in here) |
| tests | R and SQL scripts used for automated testing at the end of each build eg that at least 23 variables were loaded, all value codes are used, all variables in the wide table have a range of distinct values, etc|

## Reusable functions and stored procedures

### SQL



### R



