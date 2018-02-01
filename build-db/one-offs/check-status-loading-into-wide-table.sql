/*
Script for checking progress of loading up the wide table one column at a time.


Peter Ellis 1 December 2017
*/

SELECT ISNULL(loaded_into_wide_table, 'Not loaded') AS loaded, * 
FROM IDI_Sandpit.pop_exp_charlie.dim_explorer_variable 
WHERE use_in_front_end = 'Use'
ORDER BY loaded

SELECT ISNULL(loaded_into_wide_table, 'Not loaded') AS loaded, grain, count(1) as freq
FROM IDI_Sandpit.pop_exp_charlie.dim_explorer_variable 
WHERE use_in_front_end = 'Use'
GROUP BY loaded_into_wide_table, grain


