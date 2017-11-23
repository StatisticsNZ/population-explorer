/*
Create a dimension table holding date information

Takes a few minutes

The source code for the stored procedure that builds this is in the ./src/ folder

*/


IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.dim_date', 'U') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.dim_date;

GO


EXECUTE IDI_Sandpit.lib.create_dim_date @schema = 'pop_exp_dev';
