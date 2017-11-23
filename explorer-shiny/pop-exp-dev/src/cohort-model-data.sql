SELECT 
x.*,
ISNULL(y.RESPVAR, 0) AS response
FROM
(SELECT *
    FROM IDI_Sandpit.SCHEMA.vw_year_wide
  WHERE birth_year_nbr = BIRTHYEAR
    AND year_nbr = YEAR1) AS x
LEFT JOIN
(SELECT 
    SQRT(ABS(RESPVAR)) * SIGN(RESPVAR) AS RESPVAR, 
    snz_uid
  FROM IDI_Sandpit.SCHEMA.vw_year_wide
  WHERE birth_year_nbr = BIRTHYEAR
  AND year_nbr = YEAR2) as y
ON x.snz_uid = y.snz_uid
