/*
This sets up a log used to store the results from the semi-automated build process.
When RStudio is running build scripts, summary of the result is stored here.

Peter Ellis, 14 November 2017

*/

CREATE TABLE IDI_Sandpit.dbo.pop_exp_build_log
(
	log_event_code INT NOT NULL IDENTITY PRIMARY KEY, 
	start_time VARCHAR(22), -- not DATETIME because that complicates the inserts
	end_time   VARCHAR(22),
	target_schema VARCHAR(30),
	script_name VARCHAR(1000),
	batch_number INT,
	result CHAR(30),
	err_mess VARCHAR(8000)
);
-- Obviously start_time and end_time should be DATETIME but it was too much bother to get R to write correctly to that format, so settling with character.
-- Good enough for a log.