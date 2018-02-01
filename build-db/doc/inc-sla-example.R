
library(RODBC)
library(ggplot2)
library(scales)

sql <- 
"

SELECT top 10000 * FROM
	-- annual incomes:
	(SELECT 
		value	AS income,
		sex,
		snz_uid,
		fk_date_period_ending
	FROM IDI_Pop_explorer.pop_exp_charlie.fact_rollup_year				AS f
	INNER JOIN IDI_Pop_explorer.pop_exp_charlie.dim_explorer_variable	AS vr
		ON f.fk_variable_code = vr.variable_code
	-- join to person dimension to get the sex attribute:
	INNER JOIN IDI_Pop_explorer.pop_exp_charlie.dim_person	AS p
		on f.fk_snz_uid = p.snz_uid
	WHERE vr.long_name = 'Income from wages and salaries' AND
		fk_date_period_ending = '2012-12-31') AS inc
INNER JOIN
	-- student loan balances:
	(SELECT 
		value	AS loan_balance,
		fk_snz_uid AS snz_uid,
		fk_date_period_ending
	FROM IDI_Pop_explorer.pop_exp_charlie.fact_rollup_year				AS f
	INNER JOIN IDI_Pop_explorer.pop_exp_charlie.dim_explorer_variable	AS vr
		ON f.fk_variable_code = vr.variable_code
	WHERE vr.long_name = 'Student loan balance') AS sla
ON inc.snz_uid = sla.snz_uid AND 
	inc.fk_date_period_ending =sla.fk_date_period_ending
-- in random order:
ORDER BY NEWID()"

# connect to database
idi <- odbcConnect("ILEED")

inc_sla <- sqlQuery(idi, sql) # about 10 seconds

png("doc/inc-sla-eg.png", 6000, 4000, res = 600)
ggplot(inc_sla, aes(x = loan_balance, y = income)) +
	geom_jitter(alpha = 0.3) +
	geom_smooth(se = FALSE) +
	facet_wrap(~sex) +
	scale_x_log10(label = dollar) +
	scale_y_log10(label = dollar) +
  ggtitle("Income versus student loan balance in 2012",
          "Example random extract of 10,000 cases from the Population Explorer")
dev.off()
