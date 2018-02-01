/*
This script populates the number_observations field in dim_explorer_variable for variables with grain = 'person'
ie those that come from dim_person.  These are a bit idiosyncratic so it's easiest to code them explicitly one
at a time.

Peter Ellis 1 December 2017
*/

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET number_observations =
	(SELECT COUNT(1) 
	FROM IDI_Sandpit.pop_exp_dev.dim_person 
	WHERE sex in ('Male', 'Female'))
WHERE short_name = 'Sex'

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET number_observations =
	(SELECT COUNT(1) 
	FROM IDI_Sandpit.pop_exp_dev.dim_person 
	WHERE born_nz = 'Birth recorded by DIA')
WHERE short_name = 'Born_NZ'


UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET number_observations =
	(SELECT COUNT(1) 
	FROM IDI_Sandpit.pop_exp_dev.dim_person 
	WHERE iwi != 'No data')
WHERE short_name = 'Iwi'


UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET number_observations =
	(SELECT COUNT(1) 
	FROM IDI_Sandpit.pop_exp_dev.dim_person 
	WHERE europ = 'European')
WHERE short_name = N'Europ'

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET number_observations =
	(SELECT COUNT(1) 
	FROM IDI_Sandpit.pop_exp_dev.dim_person 
	WHERE maori = N'Māori')
WHERE short_name = N'Māori'

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET number_observations =
	(SELECT COUNT(1) 
	FROM IDI_Sandpit.pop_exp_dev.dim_person 
	WHERE asian = 'Asian')
WHERE short_name = N'Asian'

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET number_observations =
	(SELECT COUNT(1) 
	FROM IDI_Sandpit.pop_exp_dev.dim_person 
	WHERE pacif = 'Pacific peoples')
WHERE short_name = 'pacif'

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET number_observations =
	(SELECT COUNT(1) 
	FROM IDI_Sandpit.pop_exp_dev.dim_person 
	WHERE melaa = 'MELAA')
WHERE short_name = 'MELAA'

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET number_observations =
	(SELECT COUNT(1) 
	FROM IDI_Sandpit.pop_exp_dev.dim_person 
	WHERE other = 'Other ethnicity')
WHERE short_name = 'Other'


UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET number_observations =
	(SELECT COUNT(1) 
	FROM IDI_Sandpit.pop_exp_dev.dim_person 
	WHERE birth_year_nbr IS NOT NULL)
WHERE short_name = 'birth_year_nbr'


UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET number_observations =
	(SELECT COUNT(1) 
	FROM IDI_Sandpit.pop_exp_dev.dim_person 
	WHERE birth_month_nbr IS NOT NULL)
WHERE short_name = 'birth_month_nbr'

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET number_observations =
	(SELECT COUNT(1) 
	FROM IDI_Sandpit.pop_exp_dev.dim_person 
	WHERE number_known_parents != 0)
WHERE short_name = 'number_known_parents'

UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET number_observations =
	(SELECT COUNT(1) 
	FROM IDI_Sandpit.pop_exp_dev.dim_person 
	WHERE parents_income_birth_year IS NOT NULL)
WHERE short_name = 'parents_income_birth_year'

GO
