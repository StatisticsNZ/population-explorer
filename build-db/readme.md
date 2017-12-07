# Building the Population Explorer database

Peter Ellis, October 2017

## Intro

Scripts in this folder are meant to run in sequential order of the numbers, and create the Population Explorer data schema from scratch.  They delete existing copies as they go so be careful!

## Schemas

You need read access to IDI_Clean and IDI_Metadata.  You need CRUD access to IDI_Sandpit and in particular these schemas

* pop_exp, pop_exp_dev and pop_exp_test (three different versions of the core database)
* intermediate (used to store expensive intermediate tables)
* dbo (used for logging)

## Build process

See build.R for the sequence that things are built in.  Note that this script let's you specify a target schema (usually one of pop_exp, pop_exp_test) for the build.

## Subfolders under build-db

* src - source code for multi-use functions and stored procedures, in both R and SQL
* int - SQL scripts for creating the "intermediate" tables
* one-offs - ad hoc useful scripts for things like inspecting the build log, identifying indexes, etc
* . - SQL scripts for creating the pop_exp schema (or pop_exp_dev and pop_exp_test) and R scripts for running them all in sequence (ie similar function to what you'd normally do with make or a SQL Server specific tool).  