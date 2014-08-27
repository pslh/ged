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

import sys, os, psycopg2, psycopg2.extensions 
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
        xls_filename = "Level_0_Europe_NERA_v1.xls"
    if os.path.exists(xls_filename):
        my_workbook = open_workbook(xls_filename)
    else:
        print "ERROR: file '%s' not found!" % xls_filename
        exit(2)

    sheets = my_workbook.sheet_names()

    query = """CREATE TEMP VIEW nera AS SELECT geographic_region_gadm.g0name AS g0name, study_region.id AS sr_id, distribution_group.id AS dg_id, study_region_facts.id AS srf_id, distribution_group.is_urban AS is_urban FROM ged2.study_region JOIN ged2.geographic_region_gadm ON study_region.geographic_region_id = geographic_region_gadm.region_id JOIN ged2.distribution_group ON distribution_group.study_region_id = study_region.id JOIN ged2.study_region_facts ON study_region_facts.distribution_group_id = distribution_group.id WHERE study_region.study_id = %s""" % (nera_study_id)
    mark.execute(query)
    # nera: g0name / sr_id / dg_id / srf_id

    ###########
    print "\nGoing to insert URBAN building_fractions into 'study_region_facts' table..."
    ###########

    mark.execute("""SELECT g0name, dg_id FROM nera WHERE is_urban = true;""")

    s = my_workbook.sheet_by_name(sheets[5])
    progress = 1
    for y in range(1, s.nrows):
        g0 = (s.cell(y,2).value)
        mark.scroll(0,mode='absolute')
        for x in mark:
            if (g0 == x[0]):
                for c in range(3, s.ncols):
                    building_type = s.cell(0,c).value
                    building_fraction = s.cell(y,c).value

                    if (g0 and building_type and building_fraction):
                        #print g0, building_type, building_fraction
                        dg_id = str(int(x[1]))
                        querydv = """SELECT id FROM ged2.distribution_value WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (dg_id, building_type)
                        mark2.execute(querydv)
                        if mark2.rowcount < 1:
                            q = """INSERT INTO ged2.distribution_value (distribution_group_id, building_type, building_fraction) VALUES (%s, '%s', %s);""" % (dg_id, building_type, building_fraction)
                        else:
                            q = """UPDATE ged2.distribution_value SET (building_fraction) = (%s) WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (building_fraction, dg_id, building_type)
                        mark2.execute(q)

        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()


    ###########
    print "\nGoing to insert URBAN building_fractions into 'study_region_facts' table..."
    ###########

    mark.execute("""SELECT g0name, dg_id FROM nera WHERE is_urban = false;""")

    s = my_workbook.sheet_by_name(sheets[6])
    progress = 1
    for y in range(1, s.nrows):
        g0 = (s.cell(y,2).value)
        mark.scroll(0,mode='absolute')
        for x in mark:
            if (g0 == x[0]):
                for c in range(3, s.ncols):
                    building_type = s.cell(0,c).value
                    building_fraction = s.cell(y,c).value

                    if (g0 and building_type and building_fraction):

                        #print g0, building_type, building_fraction
                        dg_id = str(int(x[1]))
                        querydv = """SELECT id FROM ged2.distribution_value WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (dg_id, building_type)
                        mark2.execute(querydv)
                        if mark2.rowcount < 1:
                            q = """INSERT INTO ged2.distribution_value (distribution_group_id, building_type, building_fraction) VALUES (%s, '%s', %s);""" % (dg_id, building_type, building_fraction)
                        else:
                            q = """UPDATE ged2.distribution_value SET (building_fraction) = (%s) WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (building_fraction, dg_id, building_type)
                        mark2.execute(q)

        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()



    ###########
    print "\nGoing to insert URBAN dwelling_fractions into 'study_region_facts' table..."
    ###########

    mark.execute("""SELECT g0name, dg_id FROM nera WHERE is_urban = true;""")

    s = my_workbook.sheet_by_name(sheets[7])
    progress = 1
    for y in range(1, s.nrows):
        g0 = (s.cell(y,2).value)
        mark.scroll(0,mode='absolute')
        for x in mark:
            if (g0 == x[0]):
                for c in range(3, s.ncols):
                    building_type = s.cell(0,c).value
                    dwelling_fraction = s.cell(y,c).value

                    if (g0 and building_type and dwelling_fraction):
                        dg_id = str(int(x[1]))
                        querydv = """SELECT id FROM ged2.distribution_value WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (dg_id, building_type)
                        mark2.execute(querydv)
                        if mark2.rowcount < 1:
                            q = """INSERT INTO ged2.distribution_value (distribution_group_id, building_type, dwelling_fraction) VALUES (%s, '%s', %s);""" % (dg_id, building_type, dwelling_fraction)
                        else:
                            q = """UPDATE ged2.distribution_value SET (dwelling_fraction) = (%s) WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (dwelling_fraction, dg_id, building_type)

                        mark2.execute(q)

        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()


    ###########
    print "\nGoing to insert RURAL dwelling_fractions into 'study_region_facts' table..."
    ###########

    mark.execute("""SELECT g0name, dg_id FROM nera WHERE is_urban = false;""")

    s = my_workbook.sheet_by_name(sheets[8])
    progress = 1
    for y in range(1, s.nrows):
        g0 = (s.cell(y,2).value)
        mark.scroll(0,mode='absolute')
        for x in mark:
            if (g0 == x[0]):
                for c in range(3, s.ncols):
                    building_type = s.cell(0,c).value
                    dwelling_fraction = s.cell(y,c).value

                    if (g0 and building_type and dwelling_fraction):
                        dg_id = str(int(x[1]))
                        querydv = """SELECT id FROM ged2.distribution_value WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (dg_id, building_type)
                        mark2.execute(querydv)
                        if mark2.rowcount < 1:
                            q = """INSERT INTO ged2.distribution_value (distribution_group_id, building_type, dwelling_fraction) VALUES (%s, '%s', %s);""" % (dg_id, building_type, dwelling_fraction)
                        else:
                            q = """UPDATE ged2.distribution_value SET (dwelling_fraction) = (%s) WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (dwelling_fraction, dg_id, building_type)

                        mark2.execute(q)

        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()


    ###########
    print "\nGoing to insert replacement_cost into 'study_region_facts' table..."
    ###########

    mark.execute("""SELECT g0name, dg_id FROM nera;""")
    s = my_workbook.sheet_by_name(sheets[7])
    progress = 1
    for y in range(1, s.nrows):
        break ##### SKIPPING FROM NERA V1.0
        g0 = (s.cell(y,2).value)
        replace_currency = (s.cell(y,3).value)
        replace_date = (s.cell(y,4).value)
        replace_source = (s.cell(y,5).value)
        mark.scroll(0,mode='absolute')
        for x in mark:
            if (g0 == x[0]):
                dg_id = -1
                for c in range(6, s.ncols):
                    building_type = s.cell(0,c).value
                    replace_cost = s.cell(y,c).value

                    if (g0 and building_type and replace_cost):
                        dg_id = str(int(x[1]))
                        querydv = """SELECT id FROM ged2.distribution_value WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (dg_id, building_type)
                        mark2.execute(querydv)
                        if mark2.rowcount < 1:
                            q = """INSERT INTO ged2.distribution_value (distribution_group_id, building_type, replace_cost_per_area) VALUES (%s, '%s', %s);""" % (dg_id, building_type, replace_cost)
                        else:
                            q = """UPDATE ged2.distribution_value SET (replace_cost_per_area) = (%s) WHERE distribution_group_id = %s AND building_type LIKE '%s';""" % (replace_cost, dg_id, building_type)
                        mark2.execute(q)

                if int(dg_id) > 0:
                    q = """UPDATE ged2.distribution_group SET (replace_cost_per_area_source, replace_cost_per_area_date, replace_cost_per_area_currency) = ('%s', '%s-01-01', '%s') WHERE id = %s;""" % (replace_source, str(int(replace_date)), replace_currency, dg_id)
                    mark2.execute(q)

        progress = progress + 1
        print ("%s%d%%" % ('\b'*4, 100*progress/s.nrows)),   
        sys.stdout.flush()

    ###########
    print "\nGoing to insert avg_dwelling_per_build into 'study_region_facts' table..."
    ###########

    mark.execute("""SELECT g0name, dg_id FROM nera;""")

    s = my_workbook.sheet_by_name(sheets[2])
    progress = 1
    for y in range(1, s.nrows):
        g0 = (s.cell(y,2).value)
        avg_dwelling_per_build = (s.cell(y,3).value)
        avg_dwelling_per_build_date = (s.cell(y,4).value)
        avg_dwelling_per_build_source = (s.cell(y,5).value)
        mark.scroll(0, mode='absolute')
        for x in mark:
            if (g0 == x[0]):
                if (g0 and avg_dwelling_per_build and avg_dwelling_per_build_date and avg_dwelling_per_build_source):
                    dg_id = str(int(x[1]))
                    q = """UPDATE ged2.distribution_value SET (avg_dwelling_per_build) = (%s) WHERE distribution_group_id = %s;""" % (avg_dwelling_per_build, dg_id)
                    mark2.execute(q)
                    q = """UPDATE ged2.distribution_group SET (avg_dwelling_per_build_date, avg_dwelling_per_build_source) = ('%s-01-01', '%s') WHERE id = %s;""" % (str(int(avg_dwelling_per_build_date)), avg_dwelling_per_build_source, dg_id)
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
