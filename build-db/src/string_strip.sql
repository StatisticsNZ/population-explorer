USE IDI_Sandpit

IF OBJECT_ID('lib.string_strip') IS NOT NULL
	DROP FUNCTION lib.string_strip
GO

-- a function to strip all the tabs, linebreaks, and spaces out of a character
-- usage is SELECT lib.string_strip(' what a	lot of spaces')

CREATE FUNCTION lib.string_strip (@x VARCHAR(8000))
RETURNS CHAR(8000)
AS
BEGIN
	-- be very careful editing this! the annoying line break inside two quotation marks is there deliberately...
	RETURN(
		REPLACE(REPLACE(REPLACE(@x, '	', ''), ' ', ''), '
', '')
	)
END
