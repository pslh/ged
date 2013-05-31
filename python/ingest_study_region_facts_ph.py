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

#
#     study_region_facts_id = study_region_facts(connection,mark,
#                                               distribution_group_id,factsxls,
#                                               nameOfTheCountry,is_urban,
#                                               arrayExcel,log,schema)

#

def study_region_facts(connection,mark,distribution_group_id,
                       factsxls,nameOfTheCountry,is_urban,arrayExcel,log,schema):
    found = False
    
    for i in arrayExcel:
        if (i[0].strip() == nameOfTheCountry.strip()):
            name = i[0]
            urban = i[1]
            rural = i[2]
            source = i[3]
            date = i[4]
            date = str(int(date)) + "-01-01" 

            avg_peop_dwelling = None
            if (is_urban):
                avg_peop_dwelling = urban
            else:
                avg_peop_dwelling = rural
            
            sys.stderr.write(" PH: {0} u={1} r={2} is={3} avg={4} dgid={5}\n".
                             format(name, urban, rural, is_urban, 
                                    avg_peop_dwelling,is_urban,
                                    distribution_group_id));
            
            selectQuery="""
                SELECT distribution_group_id, avg_peop_dwelling, 
                    avg_peop_dwelling_source 
                  FROM {0}.study_region_facts 
                 WHERE distribution_group_id ={1}
                 """.format(schema,distribution_group_id);
            mark.execute(selectQuery)
            results = mark.fetchone()
            if (results):
                print "#5 study_region_facts Found..." + str(distribution_group_id) + nameOfTheCountry
                found = True
            else:
                print "I will insert ", nameOfTheCountry, distribution_group_id, avg_peop_dwelling, source
                if (avg_peop_dwelling):
                    insertQuery = """
                    INSERT INTO {0}.study_region_facts(
                        distribution_group_id, 
                        avg_peop_dwelling, 
                        avg_peop_dwelling_source,
                        avg_peop_building_date
                        )
                    VALUES ({1},{2},{3},'{4}');
                    """.format(schema,distribution_group_id, 
                                 avg_peop_dwelling, avg_peop_dwelling,date)
                    
                    print insertQuery
                    mark.execute(insertQuery)
                    #results = mark.fetchone()
                    print "#5 study_region_facts Inserted " + str(distribution_group_id)
                    found = True
                else:
                    log.append(str(nameOfTheCountry) + " " + str(avg_peop_dwelling))
                    
        
    if not(found):
        log.append(nameOfTheCountry)

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

    
conString="dbname=ged user="+ usr +" password="+ passwd + " host="+ \
    database + " port=" + port
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
        date = (s.cell(row,5).value)
        source = (s.cell(row,6).value)
        #add data
            #roof = (s.cell(0,col).value)
        if (name):
            print name,urban,rural,source
            
            arrayExcel.append([name,urban,rural,source,date])


#
# TODO add AND occupancy_id=0 TO either WHERE or JOIN or something
# TODO make sure we add correct value for urban/rural - currently NOT distinguishing
#
selectQuery = """
SELECT  country.name AS country_name, 
        dg.id AS distribution_group_id ,
        dg.is_urban AS distribution_is_urban,
        facts.id AS study_region_facts_id
    FROM ged2.distribution_group AS dg
    JOIN ged2.study_region AS sr
      ON sr.id = dg.study_region_id
    JOIN ged2.geographic_region AS region
      ON region.id = sr.geographic_region_id
    JOIN ged2.gadm_country AS country
      ON country.id = region.gadm_country_id
    LEFT JOIN ged2.study_region_facts AS facts
      ON facts.distribution_group_id = dg.id
WHERE dg.occupancy_id=0 AND facts.id IS NULL
ORDER BY country.name, dg.is_urban
"""
mark.execute(selectQuery)
results = mark.fetchall()

for record in results:
    nameOfTheCountry = record[0]
    distribution_group_id = record[1]
    is_urban = record[2]
    sys.stderr.write(" PH1: {0} is={1} dgid={2}\n".
                     format(nameOfTheCountry,
                            is_urban,distribution_group_id));

    
    study_region_facts_id = study_region_facts(connection,mark,
                                               distribution_group_id,factsxls,
                                               nameOfTheCountry,is_urban,
                                               arrayExcel,log,schema)

log = list(set(log))
mark.close()
connection.commit()
connection.close()
print log
        
#python ingest_study_region_facts.py GED4GEM_Country_average_dwelling_size_23apr13.xls ged2test
        