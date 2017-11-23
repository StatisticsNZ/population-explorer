-- foreign key constraints from all the code variables to dim_explorer_value should help the query optimizer; and it also works as an
-- integrity check.  These foreign key constraints take about 20 minutes to add in.  They should be avoided if you are in dev mode ie
-- adding more variables to the fact table as they will definitely slow it down.
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (snz_uid) REFERENCES IDI_Sandpit.pop_exp_dev.dim_person(snz_uid);

ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (sex_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (born_nz_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (iwi_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (europ_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (maori_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (pacif_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (asian_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (melaa_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (other_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);

ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (income_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (hospital_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (region_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (ta_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (victimisations_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (days_nz_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (age_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (resident_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (days_nz_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (acc_claims_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (acc_value_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (offences_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (qualifications_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (mental_health_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (abuse_events_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (placement_events_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (education_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (student_loan_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (income2_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (self_employed_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (rental_income_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD FOREIGN KEY (wages_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_value(value_code);
