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

import sys
import os 
reload(sys)
sys.setdefaultencoding('utf-8')

sys.path.append('libs/errorhandler-1.1.1')
sys.path.append('libs/xlrd-0.8.0')
sys.path.append('libs/xlutils-1.5.2')
sys.path.append('libs/xlwt-0.7.4')


import psycopg2
#import shutil
#import unittest
import datetime
import getpass

#read_parameter_from_file
homepath = os.getenv("HOME")
localparamfile = homepath + "/.param_calc"
if (os.path.exists(localparamfile)):
    param = open(localparamfile,"r")
    database=param.readline()
    port=param.readline()
    usr=param.readline()
    passwd = param.readline()
    pagerExcel=(param.readline()).replace("\n","")
else:
    pagerExcel=raw_input("Enter the PAGER or GEM filename es. [Jaiswal_12302012_Structure_Type_Mapping_Wall_vs_Roof_Material_v0.2.xlsx] : ")
    database=raw_input("Enter the database address es. [ged.ciesin.columbia.edu] : ")
    port=raw_input("Enter the database port es. [5432] : ")
    usr=raw_input("Enter Your User: ")
    passwd = getpass.getpass("passwd:%s:" % usr)


from xlrd import open_workbook
conString="dbname=ged user=" + usr + " password="+ passwd + " host="+ database + " port=" + port
connection = psycopg2.connect(conString)
mark = connection.cursor()

def addLogMsg(arraymsg,msg):
    if msg not in arraymsg:
        arraymsg.append(msg)
    return arraymsg
    
    
def levenshtein(a,b):
    "Calculates the Levenshtein distance between a and b."
    n, m = len(a), len(b)
    if n > m:
        # Make sure n <= m, to use O(min(n,m)) space
        a,b = b,a
        n,m = m,n
        
    current = range(n+1)
    for i in range(1,m+1):
        previous, current = current, [i]+[0]*n
        for j in range(1,n+1):
            add, delete = previous[j]+1, current[j-1]+1
            change = previous[j-1]
            if a[j-1] != b[i-1]:
                change = change + 1
            current[j] = min(add, delete, change)
            
    return current[n]

def stefanoComparison(a,b):
    value = 0.0
    tot = len(str(a))
    for i in range(0,len(a)):
        if ((i<len(a)) and (i<len(b))):
            if (str(a[i]) == str(b[i])):
                ###print str(a[i]),str(b[i])
                value = value + 1
        else:
            return value
    
    value = (float(value/tot))*100
    ###print value,a,b
    #exit()
    return value

    
    
def checkLevenshtein(arraymsg,region,countryId,connection,mark,stampa,string_compare): 
    querya = "SELECT id, \"name\" \
        FROM eqged.gadm_admin_1 \
        where gadm_country_id = " + str(countryId)
    queryb = "SELECT \
            gadm_admin_2.id,\
            gadm_admin_2.name \
            FROM eqged.gadm_admin_1\
            INNER JOIN eqged.gadm_admin_2 on eqged.gadm_admin_1.id = eqged.gadm_admin_2.gadm_admin_1_id\
            where gadm_country_id =" +  str(countryId) + " and \
            (eqged.gadm_admin_2.\"name\" = '"+ (region.replace("'","''")) + "' OR eqged.gadm_admin_2.varname = '" + (region.replace("'","''")) + "')"
    
    mark.execute(querya)
    ###print querya
    results = mark.fetchall()
    id = None
    nome = None
    compare = 0
    for result in results:
        value1 = stefanoComparison(region,result[1].encode('latin-1'))
        value2 = levenshtein(region,result[1].encode('latin-1'))
        #value = (value1 + 1.0)/value2
        value = value1
        ###print region,result[0],result[1],value
        if (value > compare):
            id=result[0]
            nome=result[1].encode('latin-1')
            compare = value
            
    if (float(compare) > float(string_compare)):
        ##print "the best adm1 is: ",nome,";",region,compare
        arraymsg = addLogMsg(arraymsg,region + " Not found in adm1,adm2 The best availabe is: " + nome + " for: "+ region + " with Matching: " + str(compare))
        #if (f):
            #f.write(region + " Not found in adm1,adm2 The best availabe is: " + nome + " for: "+ region + " with Matching: " + str(compare) + " " + "\n")
        return id,None
    else:
        
        mark.execute(queryb)
        ###print querya
        results = mark.fetchall()
        id = None
        nome = None
        compare = 0
        for result in results:
            value1 = stefanoComparison(region,result[1].encode('latin-1'))
            value2 = levenshtein(region,result[1].encode('latin-1'))
            #value = (value1 + 1.0)/value2
            value = value1
            ###print region,result[0],result[1],value
            if (value > compare):
                id=result[0]
                nome=result[1].encode('latin-1')
                compare = value
                      
        if (float(compare) > float(string_compare)):
            ##print "the best adm2 is: ", nome,";",region,compare
            arraymsg = addLogMsg(arraymsg,region + " Not found in adm1,adm2 The best availabe is: " + nome + " for: "+ region + " with Matching: " + str(compare))
            #if (f):
                #f.write(region + " Not found in adm1,adm2 The best availabe is: " + nome + " for: "+ region + " with Matching: " + str(compare) + " " + "\n")
            return id,None
        else:
            return None
    

def getPositionWallRoofCrosstab(wb,admin):
    textArray = ["Main material of wall * Main material of roof Crosstabulation", \
                   "Main wall material * Main roof material Crosstabulation", \
                    "Wall or building material * Roof material Crosstabulation", \
                    "Wall material * Roof material Crosstabulation", \
                    "Wall Materials * Roof Materials Crosstabulation", \
                    "Main material of the walls * Main material of the roof Crosstabulation", \
                    "Wall materials * Roof materials Crosstabulation", \
                    "Wall material * Roof material Crosstabulation", \
                    "Main material of wall * Main material of roof Crosstabulation", \
                    "Main wall material * Main roof material Crosstabulation", \
                    "Main wall material * Main roof material Crosstabulation", \
                    "Wall or building material * Roof material Crosstabulation", \
                    "Main wall material * Main roof material Crosstabulation", \
                    "Main wall material * Main roof material Crosstabulation", \
                    "Wall materials * Main material of roof Crosstabulation"]
    if (admin == 'region'):
        found = False
        counter = 0
        dataset = None
        for s in wb.sheets():
            ###print 'Sheet:',s.name
            for row in range(s.nrows):
                values = []
                for col in range(s.ncols):
                    try:
                        cell = s.cell(row,col)
                        refVal = str(cell.value)
                        #print refVal
                        #print "counter:",counter
                        if ((counter == 1) and (refVal in textArray)):
                            found = True
                            counter = counter + 1
                            #print "FOUND!!", cell,row,col
                            dataset = cell,row,col
                             
                        if ((counter == 0) and (refVal in textArray)):
                            found = True
                            dataset = cell,row,col
                            counter = counter + 1
                        

                    except:
                    # value was valid ASCII data
                        pass
        if not (found):
            print "Wall Roof Not Found"
            return found
        else:
            print "qu0"
            #print "this",dataset
            return dataset
    else:
        found = False
        for s in wb.sheets():
            ##print 'Sheet:',s.name
            for row in range(s.nrows):
                values = []
                for col in range(s.ncols):
                    try:
                        cell = s.cell(row,col)
                        refVal = str(cell.value)
                        if (refVal in textArray):
                            found = True
                            return cell,row,col
                    except:
                    # value was valid ASCII data
                        pass
        if not (found):
            return found
            
def getArrays(s,regionStaringRow,roofMaterialRow):
    materialsArray = []
    totalsAreaRegion=[]
    for row in range(regionStaringRow,s.nrows):
        #area
                
        if ((s.cell(row,0)).value):
            area = (s.cell(row,0)).value
        #if (area == "Step IV"):
        if area.startswith( "Step" ):
            ###print materialsArray
            ###print totalsAreaRegion
            return materialsArray,totalsAreaRegion
           
           
        if ((s.cell(row,1)).value):
            
            region = (s.cell(row,1)).value
            
        mainMatofWall = (s.cell(row,3)).value
        #get column combination
        for col in range(4,s.ncols):
            colMaterialName = (s.cell(roofMaterialRow,col)).value
            value = (s.cell(row,col)).value
            #if (colMaterialName == "Total"):
            if ((value) and (value > 0) and (colMaterialName) and (mainMatofWall)):
                ###print row,area,region,mainMatofWall,colMaterialName,value
                materialsArray.append([row,area,region,mainMatofWall,colMaterialName,value])
        
        if ((s.cell(row,2)).value == "Total"):
            ###print "eccoooo"
            for colx in range(4,s.ncols):
                if ((s.cell(roofMaterialRow-1,colx)).value == "Total"):
                    valuex = (s.cell(row,colx)).value
                    totalsAreaRegion.append([area,region,valuex])
                    ###print totalsAreaRegion
                    #exit()
def getTotalinInList(area,region,array):
    for f in array:
        ##print f
        if ((area == f[0]) and (region == f[1])):
            return f[2]


def getCountryName(wb):
    for s in wb.sheets():
        for row in range(s.nrows):
            value = str(s.cell(row,0).value)
            if (value == "Name of the Country"):
                return str(s.cell(row,1).value)
            
def getYearCompiled(wb):
    for s in wb.sheets():
        for row in range(s.nrows):
            value = str(s.cell(row,0).value)
            if (value == "Year Compiled"):
                return str(s.cell(row,1).value)
    return None

def buildPAgerArray(wbPager):
    rowRoofName=0
    colWallName=0
    arrayPager = []
    for s in wbPager.sheets():
        for row in range(1,s.nrows):
            for col in range(1,s.ncols):
                value = (s.cell(row,col).value)
                wall = (s.cell(row,0).value)
                roof = (s.cell(0,col).value)
                arrayPager.append([wall,roof,value])
    return arrayPager

def getPagerValue(arraymsg,wall,roof,pagerArray,compare):
    ###print "searching..",wall," __vs.__ ",roof
    b = str(wall).lstrip().rstrip().lower().replace(" ","")
    d = str(roof).lstrip().rstrip().lower().replace(" ","")
     
    x=None
    for i in pagerArray:
        a = str(i[0]).lstrip().rstrip().lower().replace(" ","")
        if (a == b):
            ###print "Found 1"
            x=a
    
    y=None
    for i in pagerArray:
        c = str(i[1]).lstrip().rstrip().lower().replace(" ","")
        if (c == d):
            ###print "Found 2"
            y=c
    
    
    
    if (not(int(compare) == 100)):
        
        if (not(x)):
            ##print "search x",wall
            value = 0
            for i in pagerArray:
                a = str(i[0]).lstrip().rstrip().lower().replace(" ","")
                lena = len(a)
                lenb = len(b)
                value1=None
                if (lena>lenb):
                    value1 = stefanoComparison(a,b)
                else:
                    value1 = stefanoComparison(b,a)
                value = value1
               # print "wall,b,a",b,a,value,compare
                if (int(value) > int(compare)):
                   # print "FOUND!!! wall,b,a",b,a,value,compare
                    compare = value
                    x = a 
            if (x):
                print "search wall :", b, "Found: ", x, "value: ",compare
        
        if (not(y)):
            ##print "search y: roof==>",roof
            value = 0
            for i in pagerArray:
                c = str(i[1]).lstrip().rstrip().lower().replace(" ","")
                lenc = len(c)
                lend = len(d)
                value1=None
                if (lenc>lend):
                    value1 = stefanoComparison(c,d)
                else:
                    value1 = stefanoComparison(d,c)
                value = value1
                #print "roof,d,c",d,c,value,compare
                if (int(value) > int(compare)):
                    #print "FOUND!!! roof,d,c",d,c,value,compare
                    compare = value
                    y = c 
            if (y):
                print "search roof :", d, "Found: ", y, "value: ",compare
        
   
    if (x and y): 
        for i in pagerArray:  
            a = str(i[0]).lstrip().rstrip().lower().replace(" ","")
            c = str(i[1]).lstrip().rstrip().lower().replace(" ","")
            if ((a == x) and (c == y)):
                ##print "Found!!!!"
                return i[2]
    else:
        if (not(x)):
            ##print "Not Found ", wall
            #print "can not find corrispondency in wall: " + wall + "\n"
            arraymsg = addLogMsg(arraymsg,"can not find corrispondency in wall: " + wall)
            #f.write("can not find corrispondency in wall: " + wall + "\n")
            
        if (not(y)):
            ##print "Not Found ", roof
            #print "can not find corrispondency in wall: " + wall + "\n"
            arraymsg = addLogMsg(arraymsg,"can not find corrispondency in roof: " + roof)
            #f.write("can not find corrispondency in roof: " + roof + "\n")
        return None
         

    
def checkCountryExist(country,connection,mark):
    query = "SELECT id_0, name_0  FROM paul.gadm2names \
               where replace(replace(\"name_0\",'''',''),' ','') = '"+(country.replace("'","")).replace(" ","")+"'"
               
    ##print query
    mark.execute(query)
    results = mark.fetchall()
    if (len(results) > 0):
        for res in results:
            return res[0]
        ##print "Found more than 1 country with name:" + country
    else:
        print "cant find country:",country
        exit()
        return None

def checkRegionExist(arraymsg,region,countryId,connection,mark,stampa):
    
    
    regionUTF8 = region
    try:
        regionUTF8 = region.encode('utf-8')
    except:
        pass
    
    try:
        region = region.encode('latin-1')
    except:
        pass    
    #region = region.encode('latin-1')
    
    
    ###print 
    gadm_admin_1_id = None
    gadm_admin_2_id = None
    #query = "SELECT id \
    #    FROM eqged.gadm_admin_1 \
    #    where gadm_country_id = " + str(countryId) + " and \
    #    ( \"name\" = '" + (regionUTF8.replace("'","''"))+ "' OR \"name\" = '" + (regionUTF8.replace("'","''")) + "')"
        
    query = "SELECT id_1 \
        FROM paul.gadm2names \
        where id_0 = " + str(countryId) + " and \
        ( \"name_1\" = '" + (regionUTF8.replace("'","''"))+ "' OR \"name_1\" = '" + (regionUTF8.replace("'","''")) + "')"
        
        
    mark.execute(query)
    results = mark.fetchall()

    if (len(results) > 1):
        for res in results:
            #if (stampa):
                ###print region + " YES adm1"
                #f.write(region + " YES adm1" + "\n")
            gadm_admin_1_id = res[0]
            return gadm_admin_1_id,None
        #if (stampa):
            ##print region + " NO Inconsistency .. too many in adm1"
            #if (f):
         #   arraymsg = addLogMsg(arraymsg,region + " NO Inconsistency .. too many in adm1")
                #f.write(region + " NO Inconsistency .. too many in adm1" + "\n")
         #   print query
        #return None
    if (len(results) == 1):
        for res in results:
            #if (stampa):
                ###print region + " YES adm1"
                #f.write(region + " YES adm1" + "\n")
            gadm_admin_1_id = res[0]
            return gadm_admin_1_id,None
    if (len(results) == 0):           
        query = "SELECT id_1, id_2 \
        FROM paul.gadm2names \
        where id_0 = " + str(countryId) + " and \
        ( \"name_2\" = '" + (regionUTF8.replace("'","''"))+ "' OR \"name_2\" = '" + (regionUTF8.replace("'","''")) + "')"
       
        mark.execute(query)
        results = mark.fetchall()
        if (len(results) == 0):
            if (stampa):
                
                ##print "Try Searching Inside Charachter", region
                ciccio = checkLevenshtein(arraymsg,regionUTF8,countryId,connection,mark,stampa,string_compare)
                if (ciccio):
                    return ciccio
                else:
                    ##print region + " NO Not found in adm1,adm2"
                    arraymsg = addLogMsg(arraymsg,region + " NO Not found in adm1,adm2")
                    #if (f):
                        #f.write(region + " NO Not found in adm1,adm2" + "\n")
                    #    print query
                
            return None
        if (len(results) == 1):
            for res in results:
                #if (stampa):
                    ###print region + " YES adm2" 
                    #f.write(region + " YES adm2" + "\n")
                gadm_admin_1_id = res[0]    
                gadm_admin_2_id = res[1]
                return gadm_admin_1_id,gadm_admin_2_id
        if (len(results) > 1):
            for res in results:
                #if (stampa):
                    ###print region + " YES adm2" 
                    #f.write(region + " YES adm2" + "\n")
                gadm_admin_1_id = res[0]    
                gadm_admin_2_id = res[1]
                return gadm_admin_1_id,gadm_admin_2_id
            #if (stampa):
            #    arraymsg = addLogMsg(arraymsg,region + "  NO Inconsistency .. 0 in adm1 too many in adm2")
                #if (f):
                 #   f.write(region + "  NO Inconsistency .. 0 in adm1 too many in adm2" + "\n")
                  #  print query
            #return None
   
#### END Functions



#### BEGIN

excel_file = str(sys.argv[1])
if (not (excel_file)):
    exit()
###print excel_file
#pagerExcel="Jaiswal_12302012_Structure_Type_Mapping_Wall_vs_Roof_Material_v0.2.xlsx"
#pagerExcel="GEM_Mapping_scheme_v2.xlsx"
log = excel_file.replace("xlsx","")
log = excel_file.replace("xls","")
log = log + ".log"
#f=open(log,'w')
arraymsg =['start']
wbPager = open_workbook(pagerExcel)
pagerArray = buildPAgerArray(wbPager)


if (len(sys.argv) > 2):
    if (str(sys.argv[2]) == "1"):
        skipUnknownPagerValueError = True
    else:
        skipUnknownPagerValueError = False
else:
    skipUnknownPagerValueError = True


string_compare = 0
if (len(sys.argv) > 3):
    string_compare = sys.argv[3]
else:
    string_compare = 55
    
wb = open_workbook(excel_file)
nameOfTheCountry = getCountryName(wb)
yearCompiled = getYearCompiled(wb)
posWRC = getPositionWallRoofCrosstab(wb,'region')

print "posWRC",posWRC


if (posWRC):
    
    ###print posWRC
    s = wb.sheets()[0]
    ###print str(posWRC[0].value)
    
    roofMaterialRow = posWRC[1]+3
    regionStaringRow = posWRC[1]+4
    wallMaterialCol = 3
    regionCol = 0
    wallMaterialCol = 2
    
    ##print "regionStaringRow",regionStaringRow,"roofMaterialRow",roofMaterialRow
    
    materialsArray,totalsAreaRegion = getArrays(s,regionStaringRow,roofMaterialRow)
    
    materialsArrayTotal=[]
    
    latestregion = ""
    gadm_country_id = checkCountryExist(nameOfTheCountry,connection,mark)
    print "qui"
    print "####Country check#########"
    foundRegion=[]
    adm1list=[]
    adm2list=[]
    adm1adm2=[]
    for i in totalsAreaRegion:
        region = i[1]
        if not (region == latestregion):
            ###print region
            check = checkRegionExist(arraymsg,region,gadm_country_id,connection,mark,True)
            if (check):
                foundRegion.append(region)
                adm1adm2.append([check[0],check[1],region])
                if (not(check[0] == None) and not(check[1] == None)):
                    adm2list.append([check[1],region])
                    
                if (check[1] == None):
                    adm1list.append([check[0],region])
            latestregion = region
    
    print adm1list
    print ""
    print adm2list
    if (len(adm1adm2) == len(adm1list) or len(adm1adm2) == len(adm2list)):
        if len(adm1adm2) == len(adm1list):
            print "will use region from list adm1"
            
        if len(adm1adm2) == len(adm2list):
            print "will use region from list adm2"
            
    else:
        print "region not completley included in adm1 or adm2"
        arraymsg.append("region not completley included in adm1 or adm2")
        for el in adm1list:
            text = "region " + el[1] + " in adm1"
            #print text
            arraymsg.append(text)
        for el in adm2list:
            #print text
            text = "region " + el[1] + " in adm2"
            arraymsg.append(text)
            
            
   
    
   
    
    print "####Material check#########"
    now_counter = 0
    for i in materialsArray: 
        now_counter = now_counter + 1 
        ###print "check", i[1],i[2],totalsAreaRegion
        total = getTotalinInList(i[1],i[2],totalsAreaRegion)
        
        #print total,i[5]
        
        ratio = i[5] / total
        i.append(total)
        i.append(ratio)
        i.append(nameOfTheCountry)
        wall = i[3]
        roof = i[4]
        pagerValue = None
        materilaSingleList=[]
        for material in pagerArray:
            if material[0] not in materilaSingleList:
                materilaSingleList.append(material[0])
        
        print len(materialsArray),now_counter,i[2] 
        while (pagerValue == None):
            ###print "Request pager value"
            ###print wall,roof
            pagerValue = getPagerValue(arraymsg,wall,roof,pagerArray,string_compare)
            if not (pagerValue):
                ###print wall,roof
                ###print "can not find corrispondency in PAGER wall or roof", wall,"|", roof,"|",nameOfTheCountry
                #f.write("can not find corrispondency in PAGER " + wall +" | " + roof + " | " + nameOfTheCountry + "\n")
                
                if skipUnknownPagerValueError:
                    pagerValue = "skip"
                else:
                
                    ##print "##### Materials Available:#####"
                    #for mat in materilaSingleList:
                        ###print mat
                    
                    ###print ""
                    ##print "wall:[",wall,"] roof:[",roof,"] combination not found"
                    
                    wall = raw_input(" Enter [Wall] or type [skip] to skip Unknown Pager Value: ")
                    if wall == "skip":
                        skipUnknownPagerValueError = True
                        pagerValue = "skip"
                    else:                   
                        roof = raw_input(" Enter Roof: ")
                             
                        print("New combination entered by user " + wall +" | " + roof + " | " + nameOfTheCountry + "\n")
                        
                        
                        
                        pagerValue = getPagerValue(arraymsg,wall,roof,pagerArray,string_compare)
                
                
        
        if ((pagerValue) and (pagerValue <> "skip")):
            region = i[2]
            if region in foundRegion:
                check = checkRegionExist(arraymsg,region,gadm_country_id,connection,mark,False)
                if (check):
                    i.append(pagerValue)
                    materialsArrayTotal.append(i)
        
       
            
            
       
    
    ####################NOTE SORTING ARRAY
    materialsArrayTotal = sorted(materialsArrayTotal, key=lambda country: country[2])
    
    arraymsg = addLogMsg(arraymsg,"END..")
    #f.write("END..")
    #f.close()
    
    data = excel_file.replace("xlsx","")
    data = excel_file.replace("xls","")
    data = data + ".data"
    
    f=open(data,'w')
    #print "###########print RESULTS################"
    materialsArrayTotalIds=[]
    for i in materialsArrayTotal:
        region = i[2]
        check = checkRegionExist(arraymsg,region,gadm_country_id,connection,mark,False)
        i.append(check[0])
        i.append(check[1])
        i.append(gadm_country_id)
        i.append(yearCompiled)
        materialsArrayTotalIds.append(i)
    for i in materialsArrayTotalIds:
        print i
    
    f.write("row;area;region;mainMatofWall;colMaterialName;value;total;ratio;nameOfTheCountry;pagerValue;adm1Id;adm2Id;countryId;yearCompiled; \n")
    
    "##convert array into an array string"
    
    for i in materialsArrayTotalIds:
        for j in i:
            f.write(str(j) + ";")
        f.write("\n")
    f.close()
        
        
##### dati completi valutare come fare le insert                
    
else:
    #print "no Main material of wall * Main material of roof Crosstabulation found..."
    print "no Main material of wall * Main material of roof Crosstabulation found..."
    arraymsg=addLogMsg(arraymsg,"no Main material of wall * Main material of roof Crosstabulation found...")
    #f.close()
    #exit()



#write log
f=open(log,'w')
for i in arraymsg:
    f.write(i)
    f.write("\n")
f.close()
