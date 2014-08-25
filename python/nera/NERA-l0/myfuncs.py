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
def run_query(query):
    my_mark = connection.cursor()
    my_mark.execute(query)
    my_mark.close()


def get_id(query):
    my_mark = connection.cursor()
    my_mark.execute(query)
    my_id = my_mark.fetchone()
    my_mark.close()
    if my_id is not None:
        return my_id[0]
    else:
        return None

def get_id_or_insert_first(query1, query2):
    my_mark = connection.cursor()
    my_mark.execute(query1)
    my_id = my_mark.fetchone()
    if my_id is not None:
        my_mark.close()
        return my_id[0]
    else:
        my_mark.execute(query2)
        my_mark.execute(query1)
        my_id = my_mark.fetchone()
        my_mark.close()
        if my_id is not None:
            return my_id[0]
        else:
           return None
