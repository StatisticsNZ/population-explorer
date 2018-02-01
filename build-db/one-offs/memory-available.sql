SELECT object_name, cntr_value 
  FROM sys.dm_os_performance_counters
  WHERE counter_name = 'Total Server Memory (KB)';