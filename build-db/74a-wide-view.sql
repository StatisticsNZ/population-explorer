/*
Creates a wide version of all the data with:
- persistent infomration on individuals as codes that link to dim_explorer_values, from link_person_extended
- changing information on individuals as continuous values in the natural names Income, Hospital, etc
- changing information on individuals as codes (ie doubling up the continuous values) with names like Income_code, Hospital_code, etc.

This is likely to be the main view used by reporting tools and mostly just needs to be linked to dim_explorer_values
for instant usefulness.

This was originally going to be a view (hence beginning with "vw_") but we will probably leave it as a materialized table.
It is very fast and simple that way and doesn't seem to take up too much space, when done with a columnstore index.

Note that this script has to be modified by hand whenever a new variable is added, in 7 places:
* 1-2: the table definition (CREATE TABLE...) gets a new column for the numeric version of the variable (if it has one) and
  also a new column for the code version
* 3-4: the  insert needs to add a row of code for the numeric column and the code column
* 5:   a new FORIEGN KEY constraint is added forcing the code column to match the value_code column in the value dimension talbe
* 6-7 both the numeric and the code column for the new variable should be added to the definition of the COLUMNSTORE INDEX

## main history:
29 September 2017 - Peter Ellis, first creation
11 October 2017   - PE, materialize as a table rather than indexed view
20 October 2017   - PE, recode columns with no data with the generic 'No data' code.
30 october 2017   - PE, add offences, make everything lower case

This can take a long time to execute (ie 12+ hours at one stage).  It has a lot of data to write.

See https://sqlsunday.com/2016/01/29/pivot-unpivot-and-performance/ for discussion on pivoting with CASE WHEN versus doing it with PIVOT.
Basically, the CASE WHEN approach allows more parallelization, and frankly is easier to read.

TODO I don't like that we have to add the variables in by hand, seems error-prone.  Alternative is to generate this script automatically.
Maybe for later.

*/

use IDI_Sandpit
IF OBJECT_ID ('pop_exp_dev.vw_year_wide') IS NOT NULL
DROP TABLE pop_exp_dev.vw_year_wide;
GO

CREATE TABLE pop_exp_dev.vw_year_wide
	(snz_uid INT NOT NULL,
	year_nbr INT NOT NULL, 
	sex_code INT, 
	born_nz_code INT, 
	birth_year_nbr INT,
	iwi_code INT,
	europ_code INT, 
	maori_code INT, 
	pacif_code INT, 
	asian_code INT, 
	melaa_code INT, 
	other_code INT,
	number_known_parents INT,
	parents_income_birth_year NUMERIC(13),
	
	
	-- continuous value variables:
	income NUMERIC(13),
	hospital INT,
	victimisations INT,
	age INT,
	benefits NUMERIC(7),
	days_nz INT,
	acc_claims INT,
	acc_value NUMERIC(8),
	offences INT,
	mental_health INT,
	abuse_events INT,
	placement_events INT,
	education     INT,
	student_loan NUMERIC(13),
	income2 NUMERIC(13),
	self_employed NUMERIC(13),
	rental_income NUMERIC(13),
	wages NUMERIC(13),

	-- categorised value variables:
	income_code INT,
	hospital_code INT,
	region_code INT,
	ta_code INT,
	victimisations_code INT,
	age_code INT,
	benefits_code INT,
	days_NZ_code INT,
	resident_code INT,
	acc_claims_code INT,
	acc_value_code INT,
	offences_code INT,
	qualifications_code INT,
	mental_health_code INT,
	abuse_events_code INT,
	placement_events_code INT,
	education_code INT, 
	student_loan_code INT,
	income2_code INT,
	self_employed_code INT,
	rental_income_code INT,
	wages_code INT,

	number_observations BIGINT);


DECLARE @no_data_code INT;	 
SET @no_data_code =	(
	SELECT value_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value
		WHERE short_name = 'No data');

		
INSERT pop_exp_dev.vw_year_wide
SELECT 
	snz_uid, 
	year_nbr, 
	sex_code, 
	born_nz_code, 
	birth_year_nbr,
	iwi_code,
	europ_code, maori_code, pacif_code, asian_code, melaa_code, other_code,
	number_known_parents,
	parents_income_birth_year,
		
	-- continuous value variables:
	SUM(CASE WHEN short_name = 'Income' THEN value ELSE NULL END) AS income,
	SUM(CASE WHEN short_name = 'Hospital' THEN value ELSE NULL END) AS hospital,
	SUM(CASE WHEN short_name = 'Victimisations' THEN value ELSE NULL END) AS victimisations,
	SUM(CASE WHEN short_name = 'Age' THEN value ELSE NULL END) AS age,
	SUM(CASE WHEN short_name = 'Benefits' THEN value ELSE NULL END) AS benefits,
	SUM(CASE WHEN short_name = 'Days_NZ' THEN value ELSE NULL END) AS days_nz,
	SUM(CASE WHEN short_name = 'ACC_claims' THEN value ELSE NULL END) AS acc_claims,
	SUM(CASE WHEN short_name = 'ACC_value' THEN value ELSE NULL END) AS acc_value,
	SUM(CASE WHEN short_name = 'Offences' THEN value ELSE NULL END) AS offences,
	SUM(CASE WHEN short_name = 'Mental_health' THEN value ELSE NULL END) AS mental_health,
	SUM(CASE WHEN short_name = 'Abuse_events' THEN value ELSE NULL END) AS abuse_events,
	SUM(CASE WHEN short_name = 'Placement_events' THEN value ELSE NULL END) AS placement_events,
	SUM(CASE WHEN short_name = 'Education' THEN value ELSE NULL END) AS education,
	SUM(CASE WHEN short_name = 'Student_loan' THEN value ELSE NULL END) AS student_loan,
	SUM(CASE WHEN short_name = 'Income2' THEN value ELSE NULL END) AS income2,
	SUM(CASE WHEN short_name = 'Self_employed' THEN value ELSE NULL END) AS self_employed,
	SUM(CASE WHEN short_name = 'Rental_income' THEN value ELSE NULL END) AS rental_income,
	SUM(CASE WHEN short_name = 'Wages' THEN value ELSE NULL END) AS wages,
	
	-- categorised value variables:
	ISNULL(SUM(CASE WHEN short_name = 'Income' THEN fk_value_code ELSE NULL END), @no_data_code) AS income_code,
	ISNULL(SUM(CASE WHEN short_name = 'Hospital' THEN fk_value_code ELSE NULL END), @no_data_code) AS hospital_code,
	ISNULL(SUM(CASE WHEN short_name = 'Region' THEN fk_value_code ELSE NULL END), @no_data_code) AS region_code,
	ISNULL(SUM(CASE WHEN short_name = 'TA' THEN fk_value_code ELSE NULL END), @no_data_code) AS ta_code,
	ISNULL(SUM(CASE WHEN short_name = 'Victimisations' THEN fk_value_code ELSE NULL END), @no_data_code) AS victimisations_code,
	ISNULL(SUM(CASE WHEN short_name = 'Age' THEN fk_value_code ELSE NULL END), @no_data_code) AS age_code,
	ISNULL(SUM(CASE WHEN short_name = 'Benefits' THEN fk_value_code ELSE NULL END), @no_data_code) AS benefits_code,
	ISNULL(SUM(CASE WHEN short_name = 'Days_NZ' THEN fk_value_code ELSE NULL END), @no_data_code) AS days_NZ_code,
	ISNULL(SUM(CASE WHEN short_name = 'Resident' THEN fk_value_code ELSE NULL END), @no_data_code) AS resident_code,
	ISNULL(SUM(CASE WHEN short_name = 'ACC_claims' THEN fk_value_code ELSE NULL END), @no_data_code) AS acc_claims_code,
	ISNULL(SUM(CASE WHEN short_name = 'ACC_value' THEN fk_value_code ELSE NULL END), @no_data_code) AS acc_value_code,
	ISNULL(SUM(CASE WHEN short_name = 'Offences' THEN fk_value_code  ELSE NULL END), @no_data_code) AS offences_code,
	ISNULL(SUM(CASE WHEN short_name = 'Qualifications' THEN fk_value_code  ELSE NULL END), @no_data_code) AS qualifications_code,
	ISNULL(SUM(CASE WHEN short_name = 'Mental_health' THEN fk_value_code  ELSE NULL END), @no_data_code) AS mental_health_code,
	ISNULL(SUM(CASE WHEN short_name = 'Abuse_events' THEN fk_value_code  ELSE NULL END), @no_data_code) AS abuse_events_code,
	ISNULL(SUM(CASE WHEN short_name = 'Placement_events' THEN fk_value_code  ELSE NULL END), @no_data_code) AS placement_events_code,
	ISNULL(SUM(CASE WHEN short_name = 'Education_events' THEN fk_value_code  ELSE NULL END), @no_data_code) AS education_code,
	ISNULL(SUM(CASE WHEN short_name = 'Student_loan' THEN fk_value_code  ELSE NULL END), @no_data_code) AS student_loan_code,
	ISNULL(SUM(CASE WHEN short_name = 'Income2' THEN fk_value_code  ELSE NULL END), @no_data_code) AS income2_code,
	ISNULL(SUM(CASE WHEN short_name = 'Self_employed' THEN fk_value_code  ELSE NULL END), @no_data_code) AS self_employed_code,
	ISNULL(SUM(CASE WHEN short_name = 'Rental_income' THEN fk_value_code  ELSE NULL END), @no_data_code) AS rental_income_code,
	ISNULL(SUM(CASE WHEN short_name = 'Wages' THEN fk_value_code  ELSE NULL END), @no_data_code) AS wages_code,

	COUNT_BIG(*) AS number_observations

FROM 
	IDI_Sandpit.pop_exp_dev.fact_rollup_year a
INNER JOIN IDI_Sandpit.pop_exp_dev.link_person_extended b
	ON a.fk_snz_uid = b.snz_uid
INNER JOIN IDI_Sandpit.pop_exp_dev.dim_explorer_variable c
	ON a.fk_variable_code = c.variable_code
INNER JOIN IDI_Sandpit.pop_exp_dev.dim_date d
	ON a.fk_date_period_ending = d.date_dt

	-- group by the person-year combination which makes up the grain of this "view"
GROUP BY snz_uid, year_nbr, sex_code, born_nz_code, birth_year_nbr,	iwi_code, 
		europ_code, maori_code, pacif_code, asian_code, melaa_code, other_code,
		number_known_parents, parents_income_birth_year

HAVING SUM(CASE WHEN short_name = 'Days_NZ' THEN value ELSE 0 END) > 0;
GO


ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD PRIMARY KEY (snz_uid, year_nbr);



-- A single big index covers the whole table, is quick to make, performs well, and doesn't use much disk space:
CREATE COLUMNSTORE INDEX col_main ON IDI_Sandpit.pop_exp_dev.vw_year_wide
	(snz_uid, 
	year_nbr, 
	sex_code, 
	born_nz_code, 
	birth_year_nbr,
	iwi_code,
	europ_code, maori_code, pacif_code, asian_code, melaa_code, other_code,
	number_known_parents,
	parents_income_birth_year,
	

	-- continuous variables:
	income,
	hospital,
	victimisations,
	age,
	benefits,
	days_nz,
	acc_claims,
	acc_value,
	offences,
	mental_health,
	abuse_events,
	placement_events,
	education, 
	student_loan,
	income2,
	self_employed,
	rental_income,
	wages,

	-- categorised value variables:
	income_code,
	hospital_code,
	region_code,
	ta_code,
	victimisations_code,
	age_code,
	benefits_code,
	days_nz_code,
	resident_code,
	acc_claims_code,
	acc_value_code,
	offences_code,
	qualifications_code,
	mental_health_code,
	abuse_events_code,
	placement_events_code,
	education_code,
	student_loan_code,
	income2_code,
	self_employed_code,
	rental_income_code,
	wages_code);

