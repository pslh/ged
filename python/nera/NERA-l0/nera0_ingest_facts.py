#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
#
# Copyright (c) 2014, GEM Foundation.
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
# This script was originally authored by Emanuele Goldoni
#
import psycopg2.extensions 
import shutil
import unittest
import datetime

import sys
reload(sys)
sys.setdefaultencoding('utf-8')

sys.path.append('libs/errorhandler')
sys.path.append('libs/xlrd')
sys.path.append('libs/xlutils')
sys.path.append('libs/xlwt')
from xlrd import open_workbook

# see http://bit.ly/1daJ8iq #or execfile('config.py')
from variables import *
from myfuncs import *


# open db connection info
if os.path.exists(local_param_file):
    param_file = open(local_param_file, "r")
    dbaddr = param_file.readline().rstrip('\n')
    port = param_file.readline().rstrip('\n')
    usr = param_file.readline().rstrip('\n')
    passwd = param_file.readline().rstrip('\n')
    dbname = param_file.readline().rstrip('\n')
    con_string = "dbname=" + dbname + " user=" + usr + " password=" + passwd + " host=" + \
        dbaddr + " port=" + port
    print "Connecting to db %s@%s:%s as %s..." % (dbname, dbaddr, port, usr)
else:
    print "ERROR: file with DB Connection Parameters not found!"
    print "Please check if './.db_con_param.dat' is present..."  
    exit(1)

connection = psycopg2.connect(con_string)
mark = connection.cursor()
mark2 = connection.cursor()
print "Connected to db!\n"

utc_datetime = datetime.datetime.utcnow()
datenow = utc_datetime.strftime("%Y-%m-%d %H:%M:%S")

try:

    xls_filename = raw_input("Enter the Excel filename [default]: ")
    if xls_filename == "":
        xls_filename = "Level_0_Europe_NERA.xls"
    if os.path.exists(xls_filename):
        my_workbook = open_workbook(xls_filename)
    else:
        print "ERROR: file '%s' not found!" % xls_filename
        exit(2)

    sheets = my_workbook.sheet_names()

    query = """CREATE TEMP VIEW nera AS SELECT geographic_region_gadm.g0name AS g0name, study_region.id AS sr_id, distribution_group.id AS dg_id, study_region_facts.id AS srf_id FROM ged2.study_region JOIN ged2.geographic_region_gadm ON study_region.geographic_region_id = geographic_region_gadm.region_id JOIN ged2.distribution_group ON distribution_group.study_region_id = study_region.id JOIN ged2.study_region_facts ON study_region_facts.distribution_group_id = distribution_group.id WHERE study_region.study_id = %s""" % (nera_study_id)
    mark.execute(query)
    # nera: g0name / sr_id / dg_id / srf_id

    ###########
    print "\nGoing to insert tot_num_buildings into 'study_region_facts' table..."
    ###########

    mark.execute("""SELECT g0name, srf_id FROM nera;""")

    s = my_workbook.sheet_by_name(sheets[0])
    progress = 1
    for y in range(1, s.nrows):
        g0 = (s.cell(y,2).value)
        tot_num_buildings = (s.cell(y,3).value)
        tot_num_buildings_date = (s.cell(y,4).value)
        tot_num_buildings_source = (s.cell(y,5).value)

        if (g0 and tot_num_buildings and tot_num_buildings_source and tot_num_buildings_date):
            tot_num_buildings = str(long(tot_num_buildings))
            tot_num_buildings_date = "%s-01-01" % str(int(tot_num_buildings_date))
            mark.scroll(0,mode='absolute')
            for x in mark:
                if (g0 == x[0]):
                    srf_id = str(int(x[1]))
                    q = """UPDATE ged2.study_region_facts SET (tot_num_buildings, tot_num_buildings_date, tot_num_buildings_source) = (%s, '%s', '%s') WHERE id = %s;""" % (tot_num_buildings, tot_num_buildings_date, tot_num_buildings_source, srf_id)
                    mark2.execute(q)

        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()

    ###########
    print "\nGoing to insert tot_num_dwellings into 'study_region_facts' table..."
    ###########

    mark.execute("""SELECT g0name, srf_id FROM nera;""")

    s = my_workbook.sheet_by_name(sheets[1])
    progress = 1
    for y in range(1, s.nrows):
        g0 = (s.cell(y,2).value)
        tot_num_dwellings = (s.cell(y,3).value)
        tot_num_dwellings_date = (s.cell(y,4).value)
        tot_num_dwellings_source = (s.cell(y,5).value)

        if (g0 and tot_num_dwellings and tot_num_dwellings_source and tot_num_dwellings_date):
            tot_num_dwellings = str(long(tot_num_dwellings))
            tot_num_dwellings_date = "%s-01-01" % str(int(tot_num_dwellings_date))
            mark.scroll(0,mode='absolute')
            for x in mark:
                if (g0 == x[0]):
                    srf_id = str(int(x[1]))
                    q = """UPDATE ged2.study_region_facts SET (tot_num_dwellings, tot_num_dwellings_date, tot_num_dwellings_source) = (%s, '%s', '%s') WHERE id = %s;""" % (tot_num_dwellings, tot_num_dwellings_date, tot_num_dwellings_source, srf_id)
                    mark2.execute(q)

        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()


    ###########
    print "\nGoing to insert avg_peop_building/dwelling into 'study_region_facts' table..."
    ###########

    mark.execute("""SELECT g0name, srf_id FROM nera;""")

    s = my_workbook.sheet_by_name(sheets[3])
    progress = 1
    for y in range(1, s.nrows):
        g0 = (s.cell(y,2).value)
        avg_peop_building = (s.cell(y,3).value)
        avg_peop_dwelling = (s.cell(y,4).value)
        avg_peop_date = (s.cell(y,5).value)
        avg_peop_source = (s.cell(y,6).value)

        if (g0 and (avg_peop_building or avg_peop_dwelling) and avg_peop_date and avg_peop_source):
            avg_peop_date = "%s-01-01" % (str(int(avg_peop_date)))
            avg_peop_source = str(avg_peop_source)
            mark.scroll(0,mode='absolute')
            for x in mark:
                if (g0 == x[0]):
                    srf_id = str(int(x[1]))
                    if avg_peop_building:
                        q = """UPDATE ged2.study_region_facts SET (avg_peop_building, avg_peop_building_date, avg_peop_building_source) = (%s, '%s', '%s') WHERE id = %s;""" % (avg_peop_building, avg_peop_date, avg_peop_source, srf_id)
                        mark2.execute(q)
                    if avg_peop_dwelling:
                        q = """UPDATE ged2.study_region_facts SET (avg_peop_dwelling, avg_peop_dwelling_date, avg_peop_dwelling_source) = (%s, '%s', '%s') WHERE id = %s;""" % (avg_peop_dwelling, avg_peop_date, avg_peop_source, srf_id)
                        mark2.execute(q)                 

        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()

    ###########
    print "\nGoing to insert avg_floor_capita/dwelling_area into 'study_region_facts' table..."
    ###########

    mark.execute("""SELECT g0name, srf_id FROM nera;""")

    s = my_workbook.sheet_by_name(sheets[4])
    progress = 1
    for y in range(1, s.nrows):
        g0 = (s.cell(y,2).value)
        avg_dwelling_area = (s.cell(y,3).value)
        avg_floor_capita = (s.cell(y,4).value)
        avg_footage_date = (s.cell(y,5).value)
        avg_footage_source = (s.cell(y,6).value)

        if (g0 and (avg_dwelling_area or avg_floor_capita) and avg_footage_date and avg_footage_source):
            avg_footage_date = "%s-01-01" % (str(int(avg_footage_date)))
            avg_footage_source = str(avg_footage_source)
            mark.scroll(0,mode='absolute')
            for x in mark:
                if (g0 == x[0]):
                    srf_id = str(int(x[1]))
                    if avg_dwelling_area:
                        q = """UPDATE ged2.study_region_facts SET (avg_dwelling_area, avg_dwelling_area_date, avg_dwelling_area_source) = (%s, '%s', '%s') WHERE id = %s;""" % (avg_dwelling_area, avg_footage_date, avg_footage_source, srf_id)
                        mark2.execute(q)
                    if avg_floor_capita:
                        q = """UPDATE ged2.study_region_facts SET (avg_floor_capita, avg_floor_capita_date, avg_floor_capita_source) = (%s, '%s', '%s') WHERE id = %s;""" % (avg_floor_capita, avg_footage_date, avg_footage_source, srf_id)
                        mark2.execute(q)                 

        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()



    # data = []
    # data.append()
    # data = list(set(data)) #get unique value
    # len(data)


    print "\nClosing connection and exiting..."
    mark.close()
    connection.commit()
    connection.close()
    exit(0)


except Exception, err:
    sys.stderr.write('ERROR: %s\n' % str(err))
    connection.close()
    exit(1)
