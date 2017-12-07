/*
Add column store indexes to the value dimension table
We do this as the very last thing because once done, you can't add data
to these tables any more (SQL Server 2012)

21 November 2017 Peter Ellis
*/


EXECUTE IDI_Sandpit.lib.add_cs_ind 'pop_exp_dev', 'dim_explorer_value_year'
