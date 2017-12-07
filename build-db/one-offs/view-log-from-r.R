
odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")


log <- sql_execute(idi, "one-offs/check-log.sql", sub_out = "dbo")
View(log)
