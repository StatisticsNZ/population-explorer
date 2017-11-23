/*

# SQL style guide


*/


-- 1. SQL key words in capitals
-- 2. One line per clause of a statement
-- 3. One indentedline per variable in SELECT statements if there's more than 3 variables (and encouraged even if there are 2 or 3)
-- 4. OK to have multiple variables in a GROUP BY and ORDER BY statement
-- 5. Finish each statement with a semi colon

-- Correct:
SELECT  
  COUNT(1) as freq, 
  snz_uid, 
  snz_dol_uid 
FROM IDI_Clean.dol_clean.movements
WHERE dol_mov_movement_ind = 'A'
GROUP BY snz_uid, snz_dol_uid
ORDER BY freq DESC; 


-- Incorrect (because freq should be on the next line):
SELECT COUNT(1) as freq, 
  snz_uid, 
  snz_dol_uid 
FROM IDI_Clean.dol_clean.movements
WHERE dol_mov_movement_ind = 'A'
GROUP BY snz_uid, snz_dol_uid
ORDER BY freq DESC; 


-- 6. (maybe?) Don't make redundant aliases that are the same as the original variable name

-- Incorrect:
SELECT  
  COUNT(1)        as freq, 
  snz_uid         as snz_uid, 
  snz_dol_uid     as snz_dol_uid
FROM IDI_Clean.dol_clean.movements
WHERE dol_mov_movement_ind = 'A'
GROUP BY snz_uid, snz_dol_uid
ORDER BY freq DESC;

-- 7. Indent


-- 8. snake_case not CamelCase for variable names

