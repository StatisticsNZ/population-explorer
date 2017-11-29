# Population Explorer datamart - builder perspective
Peter Ellis
29 November 2017

This document outlines the approach to building the Population Explorer datamart.  It should be read in conjunction with the accompanying "Population Explorer datamart - user perspective" which outlines the datamart's structure, defines the variables in each table, etc.

Most of the documentation for this project is in comments for each relevant script.  This document is only to provide an overview.  For example, this document does not provide detail on all the tests run at the end of each build; see the file `./build-db/tests/all-test.R` for that.

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
- `dbo` holds: 
	- the build log which includes which script was run, its target schema (eg `pop_exp_bravo`), source database (IDI_Clean or IDI_Sample), duration, result and any error message
	- a lookup table of random numbers from 0 to 300 matching to all six digit numbers used in the generation of random seeds
	
The datamart is built by R running a (long) sequence of SQL scripts.  R functions:

- load up each SQL script in sequence
- split it into batches based on where `GO` has been used in the script, 
- substitute the name of the schema that is to be built (eg `pop_exp_bravo`) for the `pop_exp_dev` used by the developer of the original SQL script
- send the batches to the database server via ODBC for execution
- records activity in a log on the database `dbo.pop_exp_build_log`

A master script `build-db\build.R` will build the whole datamart from scratch with a single click.  Parameters set at the top of that script indicate 

- which schema is to to be the target (eg `pop_exp_alpha`), 
- whether the source data is to come from the `IDI_Clean` database or the 1/100 sampled version `IDI_Sample` database
- `spine_to_sample_ratio` which further limits the data eg 10 means 1 / 10 sample of the IDI is used as the basis for `pop_exp_xxx`

The R servers have relatively stable connections to the database and can be left connected and running scripts overnight.  R is also more flexible than pure SQL for running tests and controlling workflow.  A deliberate decision has been taken to use hand-coded SQL rather than a specialist Extract-Transform-Load toolkit so:

- the scripts creating each variable are transparent and understandable to researchers
- the datamart can be maintained and enhanced by the Integrated Data team in Stats NZ with the tools to hand.

A full build of `intermediate` takes about 20 hours.  A full build of `pop_exp` with a `spine_to_sample_ratio` of 1 takes between 14 and 40 hours on top of that.

## What you need

We deliberately built this with tools that are generally available and understandable by analysts and statisticians rather than data warehouse specialists.  In phase 1, this is what we needed:

### Database permissions:

- Create, Read, Update and Destroy access to IDI_Sandpit and to IDI_Sample on `wtstsql35` ("BigTest") for everything below the database level (eg don't need to create a database, but do need to be able to create and destroy schemas, tables, views, indexes, etc)
- Read access to IDI_Clean on `wtstsql35` and *a* copy of IDI_Metadata (currently this isn't on `wtstsql35` but one day it should be)
- Permissions to execute stored procedures and functions (I think this is not usual for Integrated Data team so needs to be asked for specifically)

### Tools

- SQL Server Management Studio 
- Access to `rstudio01` and `rstudio02`
- TortoiseSVN for managing SubVersion version control

## Folder structure

The source code for the Population Explorer is nearly all SQL, with some R used for integration - running the build and test process.  

The working version of the code is `\\wprdsql35\input_IDI\Population Explorer\build-db`.  The `Population Explorer` directory system, of which `build-db` is the sub-system holding the code that builds the database, is a checked out version of the SVN repository that lives at `\\wprdsql35\input_IDI\pop-exp-svn`.  There is no need to touch `\\wprdsql35\input_IDI\pop-exp-svn`; all work can be done in `\\wprdsql35\input_IDI\Population Explorer\build-db`.  A clone of the whole repository also exists in `\\wprdfs09\IMR-Data\IMR2017-05\checking\peter_ellis\pop-exp-svn-clone`.  This version is used for output checking prior to updating the external copy on GitHub.

The subdirectories under `build-db` have the following purposes:

| Folder | Purpose |
|--------|---------|
| 00-src | Holds source code of re-usable user-defined stored procedures and functions. |
| 01-int-tables | Holds SQL scripts that create the tables in the `intermediate` schema.   |
| 02-setup | Holds SQL scripts that delete any existing version of the database in the target schema, creates the `dim_date`, `dim_explorer_variable`, `dim_explorer_value_year`, `dim_explorer_value_qtr`, `dim_person`, `fact_rollup_year` and `fact_rollup_qtr` tables.  `dim_date` and `dim_person` are the only tables populated at this point; the others are empty or nearly empty. For example, `dim_explorer_variable` is given a single row of data at this point, the "Generic" variable which is connected to "No data" in the value table, and also is used to hold information such as the `spine_to_sample_ratio` for this instance of the datamart. Primary keys and indexes are added to `dim_person`, `dim_date`, `dim_explorer_value_XXX` and `dim_explorer_variable` but not to the fact tables.  The fact tables are to be unindexed heaps during the build process for speed while inserting data.  |
| 03-year-facts | SQL scripts that populate `fact_rollup_year`, `dim_explorer_variable` and `dim_explorer_value_year`.  One script per variable (eg "Income all sources" is a single variable, with a single script in `03-year-facts`).
| 04-year-pivot | SQL scripts that add indexes to `fact_rollup_year`, columnstore indexes to `dim_explorer_value_year` (now it is finished being added to) and pivot the data into the `vw_year_wide` table that is used by the front end and is expected to be used by researchers.  Note the name of this table implies it is a view, and it originally was; but it has been materialized as a table for performance.  Indexed views cannot have columnstore indexes in SQL Server 2012, and a columnstore index is essential for this wide table to deliver any acceptable query performance. Final steps in this stage included adding foreign key constraints to the wide "view" and columnstore indexes to it and to `dim_explorer_variable` (this can only happen now because that table is added to during the pivoting process; as each variable is added to the wide table it is recorded in `dim_explorer_variable.loaded_into_wide_table` as "Loaded"; this is to make it possible to resume from where it got up to if there is a problem, as generally happens when working with the full data). |
| 06-qtr-facts | Populate `fact_rollup_qtr` and `dim_explorer_value_qtr`.  Only variables that were already added to the yearly version are added to the quarterly, so `dim_explorer_variable` doesn't change during the load of quarterly data |
| doc | Documentation including snapshots of database diagrams, an Excel workbook with selected columns from `dim_explorer_variable` that is built and formatted by R as part of the build process, and this document |
| one-offs | Mostly this is SQL scripts that are not essential for the build process but which contain useful utilities (eg `check-log.sql`, `find-variables-with-duplicate-values-per-person.sql`, `spare-disk-space.sql`.  This also contains an R script that created the random number table, and some R utility analysis such as `examine-timings.R` used to analyse performance based on times recorded in the log for sample queries.|
| output | Images and files from analysis (not much in here) |
| tests | R and SQL scripts used for automated testing at the end of each build eg that at least 23 variables were loaded, all value codes are used, all variables in the wide table have a range of distinct values, etc|

## Reusable functions and stored procedures

### SQL

SQL has two types of user-defined functionality used in this project:

- functions take inputs and return outputs
- stored procedures have side effects (such as creating a table or an index)

| Name |  Type | Purpose |
|-----|------|-------|
| `lib.add_cs_ind` | Procedure | Creates a columnstore index on a table, using all of the columns in that table.  Used extensively. |
|  `lib.check_enough_rows` | Procedure | Throws an error if there are less than 1,000 rows in the fact table for a given variable in the variable dimension table.  Not used as it is prohibitively slow. |
| `lib.clean_out_all` | Procedure | Removes all facts, values, and variable attributes associated with a given variable from both the quarterly and annual versions.  Used during development to avoid multiple iterations of a variable. |
| `lib.clean_out_qtr` | Procedure | Removes all facts and values associated with a given variable from just `fact_rollup_qtr` and `dim_explorer_value_qtr`. |
| `lib.remove_var` | Procedure | Removes values and variable information associated with a particular variable, but does not remove anything from the main fact table.  Used during development for variables like sex and ethnicity that do not have facts in the person-variable-period fact table, but do need to be given entries in the value table. |
| `lib.remove_spell_overlaps` | Table-valued function | For a given table structure of spells, remove the overlap between spells.  Not used because it is prohibitively slow compared to repeating the code in a script. |
| `lib.string_split` | Table-valued function | Splits a comma-separated text string into a table with a row for each value.  Used in the process that matches up the information on source tables in dim_explorer_variable with the linkage rates. |
| `lib.string_strip` | Function | Strips all the tabs, linebreaks and spaces out of a character string. Also used in matching information on source tables to linkage rates |

In addition to the above multi-use functions, many of the SQL scripts create use-once stored procedures, execute them, and then drop them.  For operations that included `WHILE BEGIN ... END` chunks, this turned out to be a safer way of packaging up functionality for running remotely from R than leaving them as scripts.  However, these procedures still need to be defined in situ so when R runs them it can make the necessary subsitutions (eg replace "pop_exp_dev" with "pop_exp_alpha").

### R

R does not distinguish between functions that are strictly functions (transform inputs to outputs) and those with side effects.

| Name | Purpose |
|-----|-------|
| `sql_execute()` | The workhorse function for the build process.  For a given SQL filename, it imports the file, splits it into batches based on the word `GO` (which is T-SQL, not ANSI SQL), performs text substitutions, etc. |
| `sql_execute_all()` | Takes all the SQL scripts in a given folder and passes them one at a time to `sql_execute` in alphabetical order (which is why scripts are generaly numbered eg 00-setup.sql, 01-something-else.sql) |
| `save_variables()` | Download `dim_explorer_variable` for a given schema, save some of the columns to Excel and format it for distribution |

## Adding variables

Each variable is defined in its own script and which does simple transformations and loads it into the coded form needed for the schema.  More complex variables such as Mental Health have the bulk of the work done in the creation of an "intermediate" table; so the script in `./build-db/03-year-facts picks up a table that has already been created from five different data sources in the IDI.

### structure of the script adding each variable

The "income" script (the first that was added) has in-line comments explaining how each variable is added.  In brief, the steps are

1. Create a temporary table that resembles the intuitive representation of the data (for example, a table with columns for `snz_uid`, `year`, and `value`).  In many cases this isn't necessary as a separate step but is done on the fly in step X below.
2. Define our variable `short_name` (eg "Income") and clean out of the database any facts, values and variable codes associated with it.  Although at this stage it is just a character value, `short_name` should be a legal column name ie no spaces.
3. Add variable details to the `dim_explorer_variable` table.  These include compulsory fields like `variable_class` and `measured_variable_description` and optional ones like `use_in_front_end` (assumed to be "Use" unless otherwise specified) and `data_type` (used in the wide version later on; assumed to be "INT" and the only other likely value is "NUMERIC(15)")
4. Grab back from that table the `variable_code` that will have been automatically assigned to it in step 3.
5. Define the categorical classifications for this variable eg "0-$1000", "$1001-$2000" etc. and insert them into `dim_explorer_value_year`.  In some cases we grab these from a previous variable (eg all the income variables use the same classifications, although they are listed separately in `dim_explorer_value_year` to simplify linking them to their variables).
6. Grab back from `dim_explorer_value_year` a lookup table of those classifications and the `variable_code` that will have been automatically assigned to each in step 5.
7. Do whatever aggregation is necessary to the data (either the temporary table from step 1, or data direct from IDI_Clean or intermediate), convert values to the value classifications decided earlier, convert them to values of `value_code`, and insert into `fact_rollup_year`

That is all that is required to add a new variable.  

### The pivot operation

The scripts in `04-year-pivot` dynamically define the wide version of the fact table, based on the contents of `dim_explorer_variable` and in particular the fields `short_name`, `use_in_front_end`, `data_type` and `grain`.

The first cut of the table is constructed of just the `snz_uid` and `year_nbr` columns plus those representing the enduring characteristics of people from `dim_person` ie sex, ethnicity, seed, etc.  The columns for all the variables with "person-period" grain are in place but filled with NULL values.  At this point the primary key is specified, creating a clustered index (on `snz_uid` and `year_nbr`).  This step takes about 20% of the entire pivotting time.  At the end of the step, the table is already at its final size on disk.

The second step is to populate the columns for each "person-period" variable.  Most have two columns (one of INT or NUMERIC data type representing a count or other continuous value; the other an INT that is the `value_code` for the categorical version of the value) but some (eg Region) have only a code, no continuous value.  These columns are populated and committed to the database one variable at a time, so if the operation is interrupted it is possible to pick up from where it left off.  As each variable is added to the pivoted table, the `loaded_into_wide_table` column for that variable in `dim_explorer_variable` is filled with "Loaded"; hence during this long operation (between 12 and 30 hours when done with the full IDI, depending on how the server is feeling) it is possible to monitor where it is up to by inspecting that table in Management Studio.

When complete, foreign keys and columnstore indexes are added.  As every column with a name ending in _code has a foreign key linking to `dim_explorer_value_year`, that is a lot of foreign key constraints.  This is mostly for ensuring database integrity at this final stage of the ETL, but might also helps the query optimizer during the frequent joins from those columns to that table.

## Integration and testing during development

More to come on this.
