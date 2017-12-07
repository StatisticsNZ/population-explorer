  SELECT log_event_code, err_mess, start_time, target_schema, script_name, batch_number, result, duration, end_time
  FROM IDI_Sandpit.dbo.pop_exp_build_log
  WHERE script_name LIKE '%sample-query%' 
	AND duration IS NOT NULL
	AND err_mess = ''
	AND script_name != 'one-offs/sample-query-times.sql'
  ORDER BY log_event_code DESC
