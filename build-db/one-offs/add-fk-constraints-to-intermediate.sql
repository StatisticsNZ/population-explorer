/*
This script would add foreign key constraints from the tables in the intermediate schema to the dim_person and dim_date
tables in the main pop_exp schema.  This would be a good thing for neatness and integrity checking but is quite computationally intensive.  
So not sure we will do it.


7 November 2017 Peter Ellis


*/


---------------------------------snz_uid foreign key constraints-----------------------------------
ALTER TABLE IDI_Sandpit.intermediate.address_mid_month
	ADD CONSTRAINT address_snz_uid
	FOREIGN KEY (snz_uid) REFERENCES IDI_Sandpit.pop_exp.dim_person(snz_uid);

ALTER TABLE IDI_Sandpit.intermediate.age_end_month
	ADD CONSTRAINT age_snz_uid
	FOREIGN KEY (snz_uid) REFERENCES IDI_Sandpit.pop_exp.dim_person(snz_uid);

ALTER TABLE IDI_Sandpit.intermediate.benefits_ye_mar
	ADD CONSTRAINT benefits_ye_mar_snz_uid
	FOREIGN KEY (snz_uid) REFERENCES IDI_Sandpit.pop_exp.dim_person(snz_uid);

ALTER TABLE IDI_Sandpit.intermediate.days_in_nz
	ADD CONSTRAINT days_nz_snz_uid
	FOREIGN KEY (snz_uid) REFERENCES IDI_Sandpit.pop_exp.dim_person(snz_uid);

ALTER TABLE IDI_Sandpit.intermediate.mha_events
	ADD CONSTRAINT mha_snz_uid
	FOREIGN KEY (snz_uid) REFERENCES IDI_Sandpit.pop_exp.dim_person(snz_uid);

ALTER TABLE IDI_Sandpit.intermediate.spells_benefits
	ADD CONSTRAINT benefits_snzuid
	FOREIGN KEY (snz_uid) REFERENCES IDI_Sandpit.pop_exp.dim_person(snz_uid);


ALTER TABLE IDI_Sandpit.intermediate.spells_nz
	ADD CONSTRAINT spells_nz_snz_uid
	FOREIGN KEY (snz_uid) REFERENCES IDI_Sandpit.pop_exp.dim_person(snz_uid);




-------------------------------date foreign key constraints--------------------------------
