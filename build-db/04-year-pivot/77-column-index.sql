-- columnstore index for our big wide "view", and for the variable table, now we're finished adding to it:
EXECUTE IDI_Sandpit.lib.add_cs_ind 'pop_exp_dev', 'vw_year_wide'
EXECUTE IDI_Sandpit.lib.add_cs_ind 'pop_exp_dev', 'dim_explorer_variable'