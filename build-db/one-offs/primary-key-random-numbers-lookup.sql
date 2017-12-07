
/*
This is a one off to add a primary key to the look up table that matches six digit user ids (ie their last six digits) to
a random number between 0 and 300
*/
ALTER TABLE IDI_Sandpit.dbo.random_numbers ALTER COLUMN six_digit_nuid INT NOT NULL 
ALTER TABLE IDI_Sandpit.dbo.random_numbers ADD PRIMARY KEY(six_digit_nuid)

