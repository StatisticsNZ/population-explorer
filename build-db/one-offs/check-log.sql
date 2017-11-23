/*

Inspect the log for progress on SQL scripts that are being run in sequence by the R server

Peter Ellis 15 November 2017
*/
SELECT TOP 1000 *
  FROM IDI_Sandpit.dbo.pop_exp_build_log
  ORDER BY log_event_code DESC