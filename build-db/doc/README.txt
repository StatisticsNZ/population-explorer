This folder holds documentation relating to the database build and use for the Population Explorer.

Two of the files here are shortcuts to documents in the Stats NZ document management system and hence not directly available in the external version

Do not hand edit the variables.csv file, it is automatically generated from the database build

variables.csv is just a nicely formatted version of the key columns of the dim_explorer_variable table in the pop_exp database.

The R function that generates this table is defined in ./src/save-variables-as-csv.R
and usage is 

R> save_variables("pop_exp_test")