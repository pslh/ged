DRAFT procedure to produce grid+population data from GRUMP raster files

01) Ensure that GDAL 1.9 is installed on the system and that you
    have > 8GB of RAM available 

02) Edit env.sh to change paths to GDAL location as appropriate

03) run the following command:
    . env.sh

03) Edit getpop.py to change paths of raster files as appropriate

04) Run the following command
    nohup python getpop.py > getpop.tsv 2>getpop-err.txt &

05) Check the error output with tail -f, once the 
    "DONE Loading Population data..." message appears 
    the script can be left to run by itself.
    
06) Wait for the python program to terminate - this will take
    several hours

06) Check the error output again, in particular ensure that 
    there are no warnings regarding mismatches for cell counts.
    The output I have (excluding warnings for NULL U/R cell
    values) is:

INFO no population values for x=43200 lon=180.004166665, skipping
DONE total cells=43201x16920 = 730960920 skipped=16920 read=730944000 expected=730944000
 water=519179643, land=211764357 sum=730944000
 urban=5789059 rural=205974179 null=1119 sum=211764357

07) Create a suitable table in the DB 

08) COPY the data 

09) Update the table to add and populate the geometry field 

10) Add a GIST index

NOTES
PH: points 07 - 10 in particular could be improved - the *.sql 
files show what I have done in Pavia, but this is by no means optimal - 
in particular I suspect it would be wiser to add the geometry field
after population using the PostGIS SELECT AddGeometryColumn syntax.
