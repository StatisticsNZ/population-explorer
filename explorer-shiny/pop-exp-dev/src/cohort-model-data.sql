/*
Return all categorical data available in YEAR1 for people born in BIRTHYEAR,
plus RESPVAR in YEAR2 for the purpose of seeing what is useful in predicting
RESPVAR.

Author: Iddibot, TODAYSDATE

PRAISE

*/


SELECT 
  ALL_CODE_VARS,
  ISNULL(y.RESPVAR, 0) AS response
  
FROM
-- the explanatory variables in YEAR1:
(SELECT *
    FROM SCHEMA.vw_year_wide
  WHERE birth_year_nbr = BIRTHYEAR
    AND year_nbr = YEAR1) AS x

LEFT JOIN

-- the response variable in YEAR2:
(SELECT 
    SQRT(ABS(RESPVAR)) * SIGN(RESPVAR) AS RESPVAR, 
    snz_uid
  FROM SCHEMA.vw_year_wide
  WHERE birth_year_nbr = BIRTHYEAR
  AND year_nbr = YEAR2) AS y

ON x.snz_uid = y.snz_uid
