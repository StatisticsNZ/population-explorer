
#---------------remove all the variable-by-variable accumulatingly large files-------------
temp_data <- list.files("synthesis/temp_data", pattern = "_w_[0-9]+\\.rda", full.name = TRUE)
unlink(temp_data)

# this leaves just original-data.rda and data_synth_w.rda, which totals about 1.4GB.  These
# can be removed by hand if you want.