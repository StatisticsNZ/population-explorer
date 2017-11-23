## Source code for the Stats NZ Population Explorer

Lead developer: Peter Ellis

This repository hosts a public version of the source code for the *Population Explorer* being developed by Stats NZ as part of the Integrated Data Infrastructure 2 project.   IDI 2 includes four workstreams:
- Access pathways
- *Information layers and confidentialisation solution*
- Fundamental redesign
- Scalable infrastructure in the cloud

The Population Explorer is the main deliverable under the *Information layers and confidentialisation solution* part of the work programme.  Development work began in September 2017 and a releasable product is scheduled to be available (although not necessarily deployed) by December 2017.

It is assumed that if you reading this, you have some familiarity with what the [Integrated Data Infrastructure](http://m.stats.govt.nz/browse_for_stats/snapshots-of-nz/integrated-data-infrastructure.aspx) is, the careful security measures based on the “Five Safes” that control access, and how researchers use the Data Lab to analyse the IDI.

### The Population Explorer is about improving usability of the IDI

Microdata is data about individual people, households or organisations.  Analysis that uses microdata needs to include steps (such as counting, averaging, or other aggregation) that remove any chance of attributing sensitive values to known individuals.  The Population Explorer is being built on the assumption that the microdata in the IDI, and the careful controls on access to it via the Data Lab, remain essentially the same.  The Population Explorer is not about giving new access to microdata, but improving existing usability of the data.

Most of the data in the IDI is in the form of events (such as “person X purchased pharmaceutical Y on 17 June 2012”) and spells (such as “person A attended the year at school B from 12 February to 17 November 2012).  A significant part of researcher time in any analysis involving the IDI is “rolling up” such events-based data into regular observations (eg quarterly or annual) of standard variables, such as “number and value of pharmaceutical purchases per year”.  Typically this involves developing familiarity with the most standard way of preparing variables that the researcher has only a secondary interest in (for example, as variables to “control” for in a statistical model attempting to understand the impact of a variable that is of primary interest to the researcher).

The fundamental idea of the Population Explorer is to perform this "roll up" for around 20 to 50 variables, at annual and (if possible) quarterly intervals, so researchers who are already in the Data Lab can save many days of work.  This version of the data, which we describe as the Population Explorer Datamart, will be available as one or more schemas on the database server in the Data Lab.   This datamart would be available to IDI researchers in the Data Lab; exactly under what process and conditions is being worked through.

The Datamart is being built with a "dimensionally modelled" data model along the lines developed by Ralph Kimball and now standard in the presentation layer of data warehouses around the world.

### The Datamart will enable two other exciting new products

The disciplined design of the Population Explorer Datamart enables the development of two additional products:
- An interactive browser-based tool (colloquially called for now “the front end”) that can do a range of safe statistical analysis, producing results compliant with Stats NZ’s disclosure control (confidentiality) requirements
- A modelled synthetic unit record file that could be publicly released for use by specialist researchers, with “made up” data with the same structure and broad statistical properties as the Datamart but without any sensitive individual information

Stats NZ is considering, in consultation with stakeholders, whether the browser-based front end can be released to one or both of Data Lab researchers and the open website. 

The intent of the synthetic version of the data is for public release.

### Structure of this repository

This is a work in progress.  Active development is under way.  As the code is released under the usual protocols for release of any material from the Data Lab, the code in the public version of this repository is likely to be at least one to three weeks behind the development version.

Note that none of this code will work for anyone else; even researchers with access to the IDI would not be able to create and run the schemas and stored procedures, for example.  It is published for transparency and to help discussion of the definition of variables.

- `build-db` SQL source code (with some R utilities) for building the database.  Around 60% of the way to deployment-readiness.
- `explorer-shiny` R source code (with some SQL inputs) for the interactive front end.  Around 90% of the way to deployment-readiness.
- `synthesis` R source code for creating a synthetic version of the data.  Around 10% of the way to deployment-readiness.
- `create-sample-IDI` SQL source code for creating a random sample small version of the IDI.  Only used during development (to run code on a smaller side database to help with testing and development).

### Disclaimer

#### Overview

The results in the Population Explorer tool, and even more so this source code, are not official statistics.  They have been created for research purposes from the Integrated Data Infrastructure (IDI), managed by Statistics New Zealand.

The opinions, findings, recommendations, and conclusions expressed are those of the authors, not Stats NZ.

Access to the anonymised data used in this study was provided by Statistics NZ under the security and confidentiality provisions of the Statistics Act 1975. Only people authorised by the Statistics Act 1975 are allowed to see data about a particular person, household, business, or organisation, and the results in this tool have been confidentialised to protect these groups from identification and to keep their data safe.
Careful consideration has been given to the privacy, security, and confidentiality issues associated with using administrative and survey data in the IDI. Further detail can be found in the Privacy impact assessment for the Integrated Data Infrastructure available from www.stats.govt.nz.

#### Use of Inland Revenue tax data

The results are based in part on tax data supplied by Inland Revenue to Statistics NZ under the Tax Administration Act 1994. This tax data must be used only for statistical purposes, and no individual information may be published or disclosed in any other form, or provided to Inland Revenue for administrative or regulatory purposes.

Any person who has had access to the unit record data has certified that they have been shown, have read, and have understood section 81 of the Tax Administration Act 1994, which relates to secrecy. Any discussion of data limitations or weaknesses is in the context of using the IDI for statistical purposes, and is not related to the data’s ability to support Inland Revenue’s core operational requirements.

---
__Copyright and Licensing__

The package is Crown copyright (c) 2016, Statistics New Zealand on behalf of the New Zealand Government, and is licensed under the MIT License (see LICENSE file).

<br /><a rel="license" href="http://creativecommons.org/licenses/by/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by/4.0/88x31.png" /></a><br />This document is Crown copyright (c) 2016, Statistics New Zealand on behalf of the New Zealand Government, and is licensed under the Creative Commons Attribution 4.0 International License. To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/ or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
