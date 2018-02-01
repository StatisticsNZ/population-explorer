/*
This script adds values to the "status" and "use_in_front_end" columns of the variable dimension

Unless the script that creates the variable sets it otherwise, we mark it "Not approved" and "Use" here.

Some variables we don't use in the front end eg meshblock (because there are too many of them for
the drop down boxes in the UI)

The first three chunks of this script sometimes fail mysteriously when called via ODBC, probably 
due to out of date ODBC drivers.

24 November 2017, Peter Ellis
*/


UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET status = 'Not approved'
WHERE status IS NULL
GO

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET use_in_front_end = 'Use'
WHERE use_in_front_end IS NULL
GO 

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET data_type = 'INT'
WHERE data_type IS NULL
GO

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET has_numeric_value = 'Has numeric value'
WHERE has_numeric_value != 'No numeric value' OR has_numeric_value IS NULL
