#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
#
# Copyright (c) 2010-2012, GEM Foundation.
#
# OpenQuake is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# OpenQuake is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with OpenQuake.  If not, see <http://www.gnu.org/licenses/>.
#

#
# This script was originally authored by Stefano Ferri of the JRC and
# subsequently modified by Paul Henshaw.of the GEM Foundation
#
import sys, os, psycopg2, getpass
import datetime

#import sys
reload(sys)
sys.setdefaultencoding('utf-8')

#select distribution_group_id, sum(dwelling_fraction) from ged2test.distribution_value group by distribution_group_id order by sum;

def gedadm1Id(connection,mark,adm1Id,countryId):
        selectQuery = ("SELECT id FROM ged2.gadm_admin_1 " 
                       "WHERE gadm_country_id = "+ str(countryId)+
                       " AND gadm_id_1 = "+str(adm1Id)+" ")
        mark.execute(selectQuery)
        results = mark.fetchone()
            ##print "#2 country inserted.." + str(results[0])
        return results[0]
    
def gedadm2Id(connection,mark,adm1Id,adm2Id,countryId):
        selectQuery = ("SELECT id FROM ged2.gadm_admin_2  WHERE gadm_id_0 = "+
                       str(countryId)+" AND gadm_admin_1_id = "+str(adm1Id)+
                       " AND gadm_id_2 = "+str(adm2Id)+" ")
        ##print selectQuery
        mark.execute(selectQuery)
        results = mark.fetchone()
            ##print "#2 country inserted.." + str(results[0])
        return results[0]
          
def study(con,mark,region,country,countryId,level,taxonomy,log,schema):
    #"Afghanistan, L0, UN Habitat"
    "Afghanistan, L0, UN Habitat"
    
    #get right name
    selectQuery = "SELECT name_0  FROM ged2.gadm2 where id_0=" + str(countryId) 
    mark.execute(selectQuery)
    results = mark.fetchone()
    ##print "#2 country found .." + str(results[0])
    country = results[0].encode('utf-8')
    country = country.replace("'","''")
    
    name=country + ", L" + str(level)+", UN Habitat"   
    
    selectQuery = ("SELECT id, name, date_created, notes FROM " + 
                    schema + ".study WHERE name='"+name+"'")
    mark.execute(selectQuery)
    results = mark.fetchone()
    if (results):
        log.append("the study " + name + "already Exist!")
        return results[0]
    else:
        utc_datetime = datetime.datetime.utcnow()
        datenow = utc_datetime.strftime("%Y-%m-%d %H:%M:%S")
        insertQuery = """INSERT INTO """ + schema + """.study(
                            name, date_created)
                            VALUES ('""" + name + """', '""" + str(datenow) + """') RETURNING id ;"""
        mark.execute(insertQuery)
        results = mark.fetchone()
        ##print "#1 " + name
        return results[0]


def geographic_region(connection,mark,adm1Id,adm2Id,countryId,level,log,nameOfTheCountry,region,row,schema):
    #sys.stderr.write("!! geographic_region a1={0} a2={1} cid={2} level={3} cname={4} region={5}\n".format(
    #   adm1Id, adm2Id, countryId,level,nameOfTheCountry,region));
    
        
    if (level == "1"):
        #sys.stderr.write("!! geographic_region: LEVEL 1\n");
        origadm1 = adm1Id
        origadm2 = adm2Id
    
        adm1Id = gedadm1Id(connection,mark,adm1Id,countryId)
        
        
        if not(adm2Id == "Null"):
            adm2Id = gedadm2Id(connection,mark,adm1Id,adm2Id,countryId)
            selectQuery = """SELECT id, gadm_country_id, gadm_admin_1_id, gadm_admin_2_id  FROM """ + schema + """.geographic_region 
                WHERE (gadm_admin_2_id = """+str(adm2Id)+""" )"""
        else:
            selectQuery = """SELECT id, gadm_country_id, gadm_admin_1_id, gadm_admin_2_id  FROM """ + schema + """.geographic_region 
                WHERE (gadm_admin_1_id = """+str(adm1Id)+""") """
                
        #sys.stderr.write("!! geographic_region: LEVEL 1, query={0}\n".format(selectQuery));
        mark.execute(selectQuery)
            
        #print "#2 looking for .. gadm_admin_1_id " + str(adm1Id) + " gadm_admin_2_id " + str(adm2Id) + " countryId " + str(countryId) + " " + nameOfTheCountry + " " + region        
        #print selectQuery
        results = mark.fetchone()
        if (results):
            #print "#2 country found .." + str(results[0]) + " gadm_admin_1_id " + str(adm1Id) + " countryId " + str(countryId) + " " + nameOfTheCountry + " " + region + " orig adm1" + origadm1 
            ##print selectQuery
            return results[0]
        else:
            if not(adm2Id == "Null"):
                
                insertQuery = "INSERT INTO " + schema + ".geographic_region(gadm_admin_2_id) VALUES ("+str(adm2Id)+") RETURNING id"
                #print insertQuery
                #sys.stderr.write("!! geographic_region: have adm2id={0}, insert={1}\n".format(adm2Id,insertQuery));
                
                mark.execute(insertQuery)
                results = mark.fetchone()
                #print "#2 country inserted.." + str(results[0]) + " gadm_admin_1_id " + str(adm1Id)   + " countryId " + str(countryId) + " " + nameOfTheCountry + " " + region + " orig adm1" + origadm1
                return results[0]  
            else:
                if not(adm1Id == "Null"):
                    insertQuery = "INSERT INTO " + schema + ".geographic_region(gadm_admin_1_id) VALUES ("+str(adm1Id)+") RETURNING id"
                    
                    #sys.stderr.write("!! geographic_region: have adm1id={0}, insert={1}\n".format(adm1Id,insertQuery));
                    #print insertQuery
                    mark.execute(insertQuery)
                    results = mark.fetchone()
                    #print "#2 country inserted.." + str(results[0]) + " gadm_admin_1_id " + str(adm1Id)   + " countryId " + str(countryId) + " " + nameOfTheCountry + " " + region + " orig adm1" + origadm1
                    return results[0]
                else:
                    return False
                
        
    elif (level == "0"):
#        sys.stderr.write("!! geographic_region level 0, countryId={0}\n".format(countryId));
        
        if (countryId is None):
            sys.stderr.write("!! geographic_region level 0, countryId=None\n");
        
        if (countryId == ""):
            sys.stderr.write("!! geographic_region level 0, countryId='', nameOfTheCountry={0}\n".format(nameOfTheCountry));


        #print countryId,"ROW", row
        selectQuery = "SELECT id, gadm_country_id, gadm_admin_1_id, gadm_admin_2_id  FROM " + schema + ".geographic_region WHERE gadm_country_id=" + str(countryId) 
        #print selectQuery
        mark.execute(selectQuery)
        results = mark.fetchone()
        if (results):
            ##print "#2 country found .." + str(results[0])
            return results[0]
        else:
            insertQuery = "INSERT INTO " + schema + ".geographic_region(gadm_country_id) VALUES ("+ str(countryId) +") RETURNING id"
            mark.execute(insertQuery)
            results = mark.fetchone()
            ##print "#2 country inserted.." + str(results[0])
            return results[0]
     

def study_region(connection,mark,study_id,geographic_region_id,taxonomy,taxonomy_ver,taxonomy_date,log,schema):
    selectQuery = "SELECT id, study_id, geographic_region_id  FROM " + schema + ".study_region WHERE study_id=" + str(study_id) + " AND geographic_region_id = " +str(geographic_region_id) 
    mark.execute(selectQuery)
    results = mark.fetchone()
    taxonomy_name = taxonomy
    taxonomy_version = taxonomy_ver
    taxonomy_date = taxonomy_date

    
    if (results):
        #print "#3 study_region Found.." + str(results[0])
        return results[0]
    else:
        insertQuery = "INSERT INTO " + schema + ".study_region(study_id, geographic_region_id, taxonomy_name, taxonomy_version, taxonomy_date) VALUES ("+str(study_id)+", "+str(geographic_region_id)+", '"+str(taxonomy_name)+"', '"+str(taxonomy_version)+"', '"+str(taxonomy_date)+"') RETURNING id"
        mark.execute(insertQuery)
        results = mark.fetchone()
        #print "#3 study_region inserted.." + str(results[0])
        return results[0]
        
def distribution_group(connection,mark,study_region_id,area,taxonomy,yearCompiled,log,region,nameOfTheCountry,geographic_region_id,schema):
    origarea= area
    if (area.strip() == 'Urban'):
        area = 'true'
    else:
        area = 'false'
    
    selectQuery = """SELECT 
                    id, 
                    is_urban, 
                    study_region_id, 
                    dwelling_fraction_source, 
                    dwelling_fraction_date 
                    FROM """ + schema + """.distribution_group
                    WHERE is_urban = '"""+str(area)+"""' AND 
                    study_region_id = """+str(study_region_id)+""" AND 
                    dwelling_fraction_source = 'UN Habitat'"""
                   
    mark.execute(selectQuery)
    results = mark.fetchone()
    if (results):
        #print "#4 distribution_group Found.." + area + " " + taxonomy + " id " + str(results[0]) + " " +origarea
        ##print results[0],area,study_region_id,geographic_region_id,region,nameOfTheCountry
        return results[0]
    else:
        insertQuery = """
        INSERT INTO """ + schema + """.distribution_group(
            is_urban, 
            occupancy_id, 
            study_region_id, 
            dwelling_fraction_source, 
            dwelling_fraction_date,
            compiled_by
           )
            VALUES (
                '"""+str(area)+"""', 
                """+str(0)+""", 
                """+str(study_region_id)+""", 
                'UN Habitat', 
                '2013-01-01',
                1
        ) RETURNING id
        """
        mark.execute(insertQuery)
        results = mark.fetchone()
        ##print results[0],area,study_region_id,geographic_region_id,region,nameOfTheCountry
        #print "#4 distribution_group Inserted.." + area + " " + taxonomy + " id " + str(results[0]) + " " + origarea
        return results[0]
        
def distribution_value(connection,mark,distribution_group_id,pagerValue,ratio,log,schema):
    selectQuery = """SELECT 
        id,
        distribution_group_id, 
        building_type, 
        dwelling_fraction  
        FROM """ + schema + """.distribution_value
        WHERE 
        distribution_group_id = """+str(distribution_group_id)+""" AND 
        building_type = '"""+str(pagerValue)+"""'"""
        
        #dwelling_fraction = """+str(ratio)
    mark.execute(selectQuery)
    results = mark.fetchone()
    if (results):
    #if (2 > 5):
        #print "#6 distribution_value Found..Azzz " + pagerValue + " " + str(ratio) + " distribution_group_id" + str(results[0])
        newfraction = float(results[3]) + float(ratio)
        if (newfraction > 0.97):
            print distribution_group_id,results[3],ratio, float(results[3]) + float(ratio)
        updateQuery =  """update 
                    """ + schema + """.distribution_value 
                    set dwelling_fraction = """ + str(newfraction) + """
                    WHERE id = """ + str(results[0])
        mark.execute(updateQuery)
        return True
    else:
        insertQuery = """
            INSERT INTO """ + schema + """.distribution_value(
                distribution_group_id, 
                building_type, 
                dwelling_fraction 
          )VALUES (
                """+str(distribution_group_id)+""", 
                '"""+str(pagerValue)+"""', 
                """+str(ratio)+""" 
            );"""
        mark.execute(insertQuery)
        
        #print "#6 distribution_value Inserted" + pagerValue + " " + str(ratio)
        return True
        
def study_region_facts(connection,mark,distribution_group_id,factsxls,nameOfTheCountry,area,arrayExcel,log,schema):
    for i in arrayExcel:
        if (i[0].strip() == nameOfTheCountry.strip()):
            name = i[0]
            urban = i[1]
            rural = i[2]
            source = i[3]
            data = i[4]
            avg_peop_dwelling = ""
            if (area == 'Urban'):
                area = 'true'
                avg_peop_dwelling = urban
            else:
                area = 'false'
                avg_peop_dwelling = rural
            
            
            selectQuery="SELECT distribution_group_id, avg_peop_dwelling, avg_peop_dwelling_source  FROM " + schema + ".study_region_facts WHERE distribution_group_id =" + str(distribution_group_id);
            mark.execute(selectQuery)
            results = mark.fetchone()
            if (results):
                #print "#5 study_region_facts Found..." + str(distribution_group_id)
                return True
            else:
                insertQuery = """INSERT INTO """ + schema + """.study_region_facts(
                    distribution_group_id, 
                    avg_peop_dwelling, 
                    avg_peop_dwelling_source
                )
                VALUES (
                    """+str(distribution_group_id)+""", 
                    """+str(avg_peop_dwelling)+""", 
                    '"""+str(source)+"""'
                );"""
                mark.execute(insertQuery)
                #results = mark.fetchone()
                #print "#5 study_region_facts Inserted " + str(distribution_group_id)
                return True



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
#    pagerExcel=param.readline()
else:
#    pagerExcel=raw_input("Enter the PAGER or GEM filename es. [Jaiswal_12302012_Structure_Type_Mapping_Wall_vs_Roof_Material_v0.2.xlsx] : ")
    database=raw_input("Enter the database address es. [ged.ciesin.columbia.edu] : ")
    port=raw_input("Enter the database port es. [5432] : ")
    usr=raw_input("Enter Your User: ")
    passwd = getpass.getpass("passwd:%s:" % usr)

conString="dbname=ged user="+usr+" password="+ passwd + " host="+ database + " port=" + port
connection = psycopg2.connect(conString)

mark = connection.cursor()    

utc_datetime = datetime.datetime.utcnow()
datenow = utc_datetime.strftime("%Y-%m-%d %H:%M:%S")

data_file = str(sys.argv[1])
#factsxls = str(sys.argv[2])
level = str(sys.argv[2])
taxonomy = str(sys.argv[3])
taxonomy_ver = str(sys.argv[4])
taxonomy_date = str(sys.argv[5])
#
# TODO use a command line arg
#
#schema = "ged2testph"
schema = "ged2"



if (not (data_file)):
    #print "qui"
    exit()
f=open(data_file,'r')
array=[]
log=[]

for line in f:
    array.append(line.split(";"))

#sys.stderr.write("!! read {0} lines into array\n".format(len(array)));

study_id_obtained = False

#
# PSLH Comment out from here
#
#excel = open_workbook(factsxls)
#arrayExcel = []
#
#for s in excel.sheets():
#    for row in range(1,s.nrows):
#        name = (s.cell(row,2).value)
#        urban = (s.cell(row,3).value)
#        rural = (s.cell(row,4).value)
#        data = (s.cell(row,5).value)
#        source = (s.cell(row,6).value)
#        #add data
#            #roof = (s.cell(0,col).value)
#        if (name):
#            ###print name,urban,rural,source
#            
#            arrayExcel.append([name,urban,rural,source,data])
# 
# PSLH Comment out until here
#

ciclo = 0
#print "size data:", len(array)
for i in array:
    #print i, len(array)
    if (ciclo > 0):
        row = i[0]
        area = i[1]
        region = i[2]
        mainMatofWall = i[3]
        colMaterialName = i[4]
        value = i[5]
        total = i[6]
        ratio = i[7]
        nameOfTheCountry = i[8]
        pagerValue = i[9]
        adm1Id = i[10]
        adm2Id = i[11]
        countryId = i[12]
        yearCompiled = int(float(i[13]))
        
        yearCompiled = "31-Dec-" + str(yearCompiled)
        
        print nameOfTheCountry,region,area,ratio
        
       
        
        if (adm1Id == "None"):
            adm1Id = 'Null'
        if (adm2Id == "None"):
            adm2Id = 'Null'
       
        if not(study_id_obtained):
            
            study_id = study(connection,mark,region,nameOfTheCountry,countryId,level,taxonomy,log,schema)
            if not(study_id):
                ##print "break #1"
                break
            else:
                study_id_obtained = True
        
        geographic_region_id = geographic_region(connection,mark,adm1Id,adm2Id,countryId,level,log,nameOfTheCountry,region,row,schema)
        if not(geographic_region_id):
            log.append("break #2")
            log.append(connection,mark,adm1Id,adm2Id,countryId,level,log,nameOfTheCountry,region)
            
            #print "break #2"
            break
             
        study_region_id = study_region(connection,mark,study_id,geographic_region_id,taxonomy,taxonomy_ver,taxonomy_date,log,schema)
        if not(study_region_id):
            #print "break #3"
            log.append("break #3")
            break
        
         
        distribution_group_id = distribution_group(connection,mark,study_region_id,area,taxonomy,yearCompiled,log,region,nameOfTheCountry,geographic_region_id,schema)
        if not(distribution_group_id):
            log.append("break #4")
            #print "break #4"
            break
        
        #study_region_facts_id = study_region_facts(connection,mark,distribution_group_id,factsxls,nameOfTheCountry,area,arrayExcel,log,schema)
        #if not(study_region_facts_id):
        #    log.append("break #5")
        #    #print "break #5"
        #    break
        
        
        distribution_value_id = distribution_value(connection,mark,distribution_group_id,pagerValue,ratio,log,schema)
        
        ##print nameOfTheCountry,region,area,distribution_group_id,ratio
        
        if not(distribution_group_id):
            log.append("break #6")
            #print ""
            ##print "break #6"
            break
    else:
        ciclo = ciclo + 1


if (len(log) == 0):
    mark.close()
    connection.commit()
    connection.close()
else:
    #print "errors",log
    out_file = open("ingestionLog.txt","a")
    out_file.write(nameOfTheCountry + "\n")
    for item in log:
        out_file.write(item + "\n")
    out_file.close() 

