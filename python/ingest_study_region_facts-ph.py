import sys, os, psycopg2
import shutil
import unittest
import datetime

import sys
reload(sys)
sys.setdefaultencoding('utf-8')


sys.path.append('libs/errorhandler-1.1.1')
sys.path.append('libs/xlrd-0.8.0')
sys.path.append('libs/xlutils-1.5.2')
sys.path.append('libs/xlwt-0.7.4')
from xlrd import open_workbook
      
def study_region_facts(connection,mark,distribution_group_id,factsxls,nameOfTheCountry,area,arrayExcel,log,schema):
    found = False
    for i in arrayExcel:
        if (i[0].strip() == nameOfTheCountry.strip()):
            name = i[0]
            urban = i[1]
            rural = i[2]
            source = i[3]
            data = i[4]
            data = str(int(data)) + "-01-01" 

            avg_peop_dwelling = ""
            if (area == 't'):
                area = 'true'
                avg_peop_dwelling = urban
            else:
                area = 'false'
                avg_peop_dwelling = rural
            
            
            selectQuery="SELECT distribution_group_id, avg_peop_dwelling, avg_peop_dwelling_source  FROM " + schema + ".study_region_facts where distribution_group_id =" + str(distribution_group_id);
            mark.execute(selectQuery)
            results = mark.fetchone()
            if (results):
                print "#5 study_region_facts Found..." + str(distribution_group_id) + nameOfTheCountry
                found = True
            else:
                print "I will insert ", nameOfTheCountry, distribution_group_id, avg_peop_dwelling, source
                if (avg_peop_dwelling):
                    insertQuery = """INSERT INTO """ + schema +""".study_region_facts(
                        distribution_group_id, 
                        avg_peop_dwelling, 
                        avg_peop_dwelling_source,
                        avg_peop_building_date
                    )
                    VALUES (
                        """+str(distribution_group_id)+""", 
                        """+str(avg_peop_dwelling)+""", 
                        '"""+str(source)+"""',
                        '"""+str(data)+"""'

                    );"""
                    
                    print insertQuery
                    mark.execute(insertQuery)
                    #results = mark.fetchone()
                    print "#5 study_region_facts Inserted " + str(distribution_group_id)
                    found = True
                else:
                    log.append(str(nameOfTheCountry) + " " + str(avg_peop_dwelling))
                    
        
    if not(found):
        log.append(nameOfTheCountry)



    ##read nameOfTheCountry
    ##select area + nameOfTheCountry
    #SELECT id, distribution_group_id, tot_num_dwellings, tot_num_dwellings_source, 
    #   tot_num_dwellings_source_date, tot_num_buildings, tot_num_buildings_source, 
    #   tot_num_buildings_source_date, avg_peop_dwelling, avg_peop_dwelling_source, 
    #   avg_peop_dwelling_source_date, avg_peop_building, avg_peop_building_source, 
    #   avg_peop_building_source_date, avg_floor_capita, avg_floor_capita_source, 
    #   avg_floor_capita_source_date, avg_dwelling_area, avg_dwelling_area_source, 
    #   avg_dwelling_area_source_date
    #FROM ged2test.study_region_facts;



homepath = os.getenv("HOME")
localparamfile = homepath + "/.param_calc"
if (os.path.exists(localparamfile)):
    param = open(localparamfile,"r")
    database=param.readline()
    port=param.readline()
    usr=param.readline()
    passwd = param.readline()
    pagerExcel=param.readline()
else:
    pagerExcel=raw_input("Enter the PAGER or GEM filename es. [Jaiswal_12302012_Structure_Type_Mapping_Wall_vs_Roof_Material_v0.2.xlsx] : ")
    database=raw_input("Enter the database address es. [ged.ciesin.columbia.edu] : ")
    port=raw_input("Enter the database port es. [5432] : ")
    usr=raw_input("Enter Your User: ")
    passwd = getpass.getpass("passwd:%s:" % usr)

    
conString="dbname=ged user="+ usr +" password="+ passwd + " host="+ database + " port=" + port
connection = psycopg2.connect(conString)

mark = connection.cursor()    

utc_datetime = datetime.datetime.utcnow()
datenow = utc_datetime.strftime("%Y-%m-%d %H:%M:%S")

factsxls = str(sys.argv[1])
schema = str(sys.argv[2])

excel = open_workbook(factsxls)
arrayExcel = []
log = []



for s in excel.sheets():
    for row in range(1,s.nrows):
        name = (s.cell(row,2).value)
        urban = (s.cell(row,3).value)
        rural = (s.cell(row,4).value)
        data = (s.cell(row,5).value)
        source = (s.cell(row,6).value)
        #add data
            #roof = (s.cell(0,col).value)
        if (name):
            print name,urban,rural,source
            
            arrayExcel.append([name,urban,rural,source,data])


#
# TODO add AND occupancy_id=0 TO either WHERE or JOIN or something
# TODO make sure we add correct value for urban/rural - currently NOT distinguishing
#
selectQuery = """
    select country_name, distribution_group_id,distribution_is_urban,study_region_facts_id from (
SELECT ged2.gadm_country.name as country_name, 
    ged2.distribution_group.id as distribution_group_id ,
    ged2.distribution_group.is_urban as distribution_is_urban,
    ged2.study_region_facts.id as study_region_facts_id
FROM ged2.distribution_group
join ged2.study_region on ged2.study_region.id = ged2.distribution_group.study_region_id
join ged2.geographic_region on ged2.geographic_region.id = ged2.study_region.geographic_region_id
join ged2.gadm_country on ged2.gadm_country.id = ged2.geographic_region.gadm_country_id
left join ged2.study_region_facts on ged2.study_region_facts.distribution_group_id = ged2.distribution_group.id
) as foo
where study_region_facts_id is null
order by country_name,distribution_is_urban
"""
mark.execute(selectQuery)
results = mark.fetchall()

for record in results:
    nameOfTheCountry = record[0]
    distribution_group_id = record[1]
    area = record[2]
    study_region_facts_id = study_region_facts(connection,mark,distribution_group_id,factsxls,nameOfTheCountry,area,arrayExcel,log,schema)

log = list(set(log))
mark.close()
connection.commit()
connection.close()
print log
        
#python ingest_study_region_facts.py GED4GEM_Country_average_dwelling_size_23apr13.xls ged2test
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        