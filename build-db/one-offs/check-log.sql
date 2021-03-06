/*

Inspect the log for progress on SQL scripts that are being run in sequence by the R server

Peter Ellis 15 November 2017
*/
SELECT TOP 1000 log_event_code, err_mess, start_time, target_schema, script_name, batch_number, result, duration, end_time
  FROM IDI_Sandpit.dbo.pop_exp_build_log
  ORDER BY log_event_code DESC

-- what have we been running today?:
SELECT COUNT(1) AS freq, target_schema, CAST(start_time AS DATE) as day
FROM IDI_Sandpit.dbo.pop_exp_build_log
GROUP BY  target_schema, CAST(start_time AS DATE)
ORDER BY day desc, freq desc

