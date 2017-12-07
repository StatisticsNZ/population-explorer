/*
This script adds values to the "status" and "use_in_front_end" columns of the variable dimension

Unless the script that creates the variable sets it otherwise, we mark it "Not approved" and "Use" here.

Some variables we don't use in the front end eg meshblock (because there are too many of them for
the drop down boxes in the UI)

24 November 2017, Peter Ellis
*/

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET status = 'Not approved'
WHERE status IS NULL

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET use_in_front_end = 'Do not use'
WHERE short_name in ('Birth_month_nbr')


UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET use_in_front_end = 'Use'
WHERE use_in_front_end IS NULL

