
The SQL scripts in this folder create a simple random sample of the IDI.   The aim of doing this is to have a smaller sized dataset to work with during development or testing.  The resulting database is about 20GB, compared to the 400GB that is the full IDI.  It has the same schema and table names as the original IDI_Clean database.

The scripts need to be run in order, and each has comments explaining what it is doing.

The overall strategy is to sample 600,000 values of snz_uid at random, with 100,000 representing individuals on the spine and 500,000 non-spine individuals (it is important to have both to be sure that code developed on this sample version of the IDI will work on the full version).  Then copies are made of all the tables of the IDI that have an snz_uid column (which is most of them), but limited to those 600,000 individuals.

Tables that don't have an snz_uid column are more problematic.  For version 0.1 we just take up to 1 million rows at random for these tables.  For most of them, that is the whole table; for others (eg hospital diagnoses) it is less than 1%, and the 1% sampled this way won't be particularly meaningful for our 1% sample of snz_uids.  Obviously there are better ways to do this but they need a few days work.

It is assumed that you have read access to the IDI_Clean database, and read/write/create/destroy access to a database called IDI_Sample.

There is an R script in the build-db RStudio project in this same code repository that runs all these IDI_Sample scripts end to end.

===========================================
Version 0.1 - 1 November 2017 - first working version.  Peter Ellis