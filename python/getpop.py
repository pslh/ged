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

from osgeo import osr, gdal
from osgeo.gdalconst import *
import sys

#
# Read GRUMP population and urban-extent data into text file
# For import into DB
#

#
# Raster file paths
#
urbanFile = '/data/ged/rebuild-pop/urban-rural/prj.adf'
popFile = '/data/ged/rebuild-pop/pop-input/prj.adf'

# get the existing coordinate system

urHandle = gdal.Open(urbanFile, GA_ReadOnly)
if urHandle is None:
	sys.stderr.write("Failed to open file {0}\n".format(urbanFile))
	sys.exit(1)

#
# Force use of float64 for population data
# Note that this requires use of GDAL 1.9 (see env.sh)
# See http://lists.osgeo.org/pipermail/gdal-dev/2006-July/009570.html
#
gdal.SetConfigOption('AAIGRID_DATATYPE', 'Float64')

popHandle = gdal.Open(popFile,GA_ReadOnly)
if popHandle is None:
	sys.stderr.write("Failed to open file {0}\n".format(popFile))
	sys.exit(1)

# Clear flag after open
gdal.SetConfigOption('AAIGRID_DATATYPE', None)

#
# Urban/rural raster meta-data
#
width = urHandle.RasterXSize
height = urHandle.RasterYSize
urbanTransform = urHandle.GetGeoTransform()
xOrigin = urbanTransform[0]
yOrigin = urbanTransform[3]
pixelWidth = urbanTransform[1]
pixelHeight = urbanTransform[5]

#
# Population raster meta-data
#
popWidth = popHandle.RasterXSize
popHeight = popHandle.RasterYSize
popTransform = popHandle.GetGeoTransform()
popXOrigin = popTransform[0]
popYOrigin = popTransform[3]
popPixelWidth = popTransform[1]
popPixelHeight = popTransform[5]

#
# Load raster files into (huge) arrays.
# For smaller machines a different approach (e.g. iterate over 
# blocks) should be used
#

urBand = urHandle.GetRasterBand(1)
sys.stderr.write('Loading Urban/Rural data...\n')
urData = urBand.ReadAsArray(0, 0, width, height)
if urData is None:
	sys.stderr.write('Failed to load Urban/Rural data...\n')
	sys.exit(1)
sys.stderr.write('DONE Loading Urban/Rural data...\n')

popBand = popHandle.GetRasterBand(1)
sys.stderr.write('Loading Population data...\n')
popData = popBand.ReadAsArray(0, 0, popWidth, popHeight)

if popData is None:
	sys.stderr.write('Failed to load Population data...\n')
	sys.exit(1)

sys.stderr.write('DONE Loading Population data...\n\n')

startx=0
starty=0

# Use for end-game testing
#startx=width-1#width-10 #30322 #22360

#
# Counters for different types of cell
# Used for validation later 
#
waterCells=0
landCells=0
skippedCells=0

urbanCells=0
ruralCells=0
nullCells=0

totalRead=0

for xOffset in range(startx,width):

	lon = ((xOffset+0.5) * pixelWidth) + xOrigin

#
#	Tried wrapping rather than skipping, but this causes duplicates
#
#	if lon > 180:
#		prevLon=lon
#		lon = -180 + (lon - 180);
#		sys.stderr.write('INFO adjusting lon from {0} to {1}\n for x={2}\n'.format(prevLon,lon,xOffset))

	popX = int((lon - popXOrigin) / popPixelWidth)

	# 
	# The urban extent and population rasters are not the same size
	# avoid walking off the edge
	#
	if popX >= popWidth:
		sys.stderr.write('INFO no population values for x={0} lon={1}, skipping\n'.format(xOffset,lon))
		skippedCells += height
		continue


	#sys.stderr.write('.')

#	for yOffset in range(height-1,starty-1,-1):
	for yOffset in range(starty,height):
		lat = ((yOffset+0.5) * pixelHeight) + yOrigin

		urValue = urData[yOffset, xOffset]
		popY = int((lat - popYOrigin) / popPixelHeight)

		if popY >= popHeight:
			sys.stderr.write(
				'INFO no population values for x={0},y={1} urValue={2}\n'.format(
				xOffset,yOffset,urValue))
			skippedCells += height-yOffset
			continue

#		sys.stderr.write(
#			'DEBUG population values for x={0},y={1} lat={2},lon={3}, popX={4},popY={5}\n'.format(
#			xOffset,yOffset,lat,lon,popX,popY))

		popValue = popData[popY, popX]
		totalRead += 1			

		isUrban=False
		if urValue == 1:
			isUrban = 'f'
			ruralCells += 1

		elif urValue == 2:
			isUrban = 't'
			urbanCells += 1

		elif urValue == 255:
			# no landCells mass
			if popValue == 0:
				waterCells += 1
				continue
			else:
				sys.stderr.write(
					'WARNING NULL U/R values for x={0},y={1}, lat={2},lon={3}, pop={4}\n'.format(
					xOffset,yOffset,lat,lon,popValue))
				isUrban='\\N' # NULL SQL code
				nullCells += 1
		else:
			sys.stderr.write(
				'ERROR Unnexpected U/R value {4} found at x={0},y={1}, lat={2},lon={3}\n'+
				' Check file format and GDAL version\n'.format(
				xOffset,yOffset,lat,lon,urValue))
			sys.exit(1)

		print str(lat)+'\t'+str(lon)+'\t'+str(popValue)+'\t'+str(isUrban)
		landCells += 1

#
# Validation checks - do our numbers add up?
#
totalCells = (width-startx) * height 
expectedCells = totalCells - skippedCells
waterAndLandCells=waterCells+landCells
urnSum=urbanCells+ruralCells+nullCells

sys.stderr.write(
	'DONE total cells={0}x{1} = {2} skipped={3} read={4} expected={5}\n'.format(
	(width-startx),height,totalCells,skippedCells,totalRead,expectedCells))

sys.stderr.write(
	' water={0}, land={1} sum={2}\n'.format(
	waterCells,landCells,waterAndLandCells))

sys.stderr.write(
	' urban={0} rural={1} null={2} sum={3}\n'.format(
	urbanCells,ruralCells,nullCells, urnSum)) 

if totalRead != expectedCells:
	sys.stderr.write('WARNING cells read={0} != total-skipped={1}\n'.format(
		totalRead,expectedCells))

if totalCells != waterAndLandCells+skippedCells:
	sys.stderr.write('WARNING total cells={0} != land+water+skipped={1}\n'.format(
		totalCells,waterAndLandCells+skippedCells))

if landCells != urnSum:
	sys.stderr.write('WARNING total land cells={0} != u+r+n={1}\n'.format(
		landCells,urnSum))

