/*
This query shows a definite structural break in the data at 1990.   Before 1990 there is very little data,
and nearly all of it is just one observation per person (ie age).
We can save a bit of space in the wide view by only including data from 1990 onwards
*/

  select 
	count(1) as number_observations, 
	count(distinct(fk_snz_uid)) as number_people, 
	fk_date_period_ending
  from IDI_Sandpit.pop_exp_sample.fact_rollup_year
  group by fk_date_period_ending
  order by fk_date_period_ending