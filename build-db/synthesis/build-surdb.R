
# This master script runs 

# load up the Excel configuration book (used during add-columns, and during the documentation)
adding_order   <- read.xlsx("synthesis/variable-relationships.xlsx", sheet = "adding-order")
expl_variables <- read.xlsx("synthesis/variable-relationships.xlsx", sheet = "variables")


source("synthesis/prep.R")        # about 10 minutes to download 100,000 people
source("synthesis/add-columns.R") # 3+ hours depending on how complex you make the modelling, controlled by variable-relationships.xlsx
source("synthesis/normalize.R")   # about 10 minutes to get the data into shape, 20 minutes to create the zip file.

# There is a manual step at this point, to upload dim_person.txt and fact_rollup_year.txt into the database.
# See the comments at the bottom of "./synthesis/normalize.R" for instructions.

# once dbo.dim_person and dbo.fact_rollup_year are in the database, we can get on 
# with the indexing and pivoting
source("synthesis/upload-and-pivot.R") # can ignore error messages about 61-allocate-status.sql, although I wish I knew why it has problems with this particular script only now

# build documentation
build_doc("synthesis/doc", "synthesis")

# remove temporary data files that are saved as each variable added
source("synthesis/cleanup.R")
       
       
       