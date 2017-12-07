/*
Set up some file partitions

Have previously created the file groups fg1, fg2 etc, and allocated file space to them each

The idea here is for the main fact table to be saved on different parts of the disk according to
its variable code - effectively the order it is put in, and a common way for querying it.
Not sure if this will help query or build performance.

*/

-- Peter Ellis 17 November 2017



USE IDI_Sandpit

-------------------For the long thin fact tables---------------------------

-- Partition function, which we will be using with the fk_variable_code of fact_rollup_year
CREATE PARTITION FUNCTION variable_code_range_pf (int)  
    AS RANGE LEFT FOR VALUES (3, 7, 11, 15, 19, 26, 35, 45, 60) ;  
GO  

CREATE PARTITION SCHEME variable_code_range_ps  
    AS PARTITION variable_code_range_pf  
    TO (fg1, fg2, fg3, fg4, fg5, fg6, fg7, fg8, fg9, fg10) ;  
GO  



---------------------For the fat, wide fact table-------------------- 
-- This big, wide table, as used by the front end, is most likely to get queries like
-- "show me everything you know about x and y in 2013" so we partition by year of the data.

CREATE PARTITION FUNCTION year_range_pf (int)  
    AS RANGE LEFT FOR VALUES (1980, 1990, 2000, 2008, 2012, 2014, 2016) ;  
GO  



CREATE PARTITION SCHEME year_range_ps  
    AS PARTITION year_range_pf  
    TO (fgw01, fgw02, fgw03, fgw04, fgw05, fgw06, fgw07, fgw08) ;  
GO  
