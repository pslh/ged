HOWTO ingest new Unified NERA data

Before we start, ensure that you have the appropriate Excel spreadsheet
with the building fractions, and so on.  

  cd nera_l0

If creating a new study, then execute a query of the form:

INSERT INTO ged2.study(
            name, date_created, notes)
    VALUES ('NERA Unified', current_timestamp, 
	'Combined or unified NERA/IMPRO study - update name and notes');

Obtain the id of the newly iserted study for NERA Unified the id is 450
The sql scripts below should be updated to set the study id

To see the list of fact and value ids associated with a given study

  psql -U my_user -d ged -f ph-check.sql

If replacing an old study remove the old entries:

  psql -U my_user -d ged -f ph-cleanup.sql

And then run the check again to ensure that there are now 0 entries.

Actually inserting the data:

If you installed the Excel and error handling libraries in a virtual
environment, activate the virtual environment for GED Python scripts 
with something like:

  workon ged

Run the following python scripts in the given order - when prompted
provide the name of the Excel spreadsheet.

  python nera0_initialize_geographic_regions.py
  python nera0_ingest_facts.py
  python nera0_ingest_dv.py

Check to see that the facts and values have been inserted:

psql -U my_user -d ged -f ph-check.sql
