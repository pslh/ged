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

from osgeo import gdal
from osgeo.gdalconst import GA_ReadOnly
import sys

#
# Raster file paths
#
_urbanFile = '/data/ged/rebuild-pop/urban-rural/prj.adf'
_popFile = '/data/ged/rebuild-pop/pop-input/prj.adf'

class RasterFile(object):
    """
    Representation of a Raster file
    """

    def _initMetaData(self):
        self.width = self._handle.RasterXSize
        self.height = self._handle.RasterYSize
        _transform = self._handle.GetGeoTransform()
        self.xOrigin = _transform[0]
        self.yOrigin = _transform[3]
        self.pixelWidth = _transform[1]
        self.pixelHeight = _transform[5]

    def _openFile(self, filepath):
        self._filepath=filepath
        
        #
        # Force use of float64 for population data
        # Note that this requires use of GDAL 1.9 (see env.sh)
        # See http://lists.osgeo.org/pipermail/gdal-dev/2006-July/009570.html
        #
        gdal.SetConfigOption('AAIGRID_DATATYPE', 'Float64')
        _handle = gdal.Open(filepath, GA_ReadOnly) # Clear flag after open
        gdal.SetConfigOption('AAIGRID_DATATYPE', None)
        return _handle

    def __init__(self,filepath):
        self._handle = self._openFile(filepath)
    
        if self._handle is None:
            raise IOError("Failed to open file {0}\n".format(filepath));
        
        self._initMetaData()
        
        
    def loadData(self):
        """
        Load raster files into a (huge) array.
        For smaller machines a different approach (e.g. iterate over 
        blocks) should be used
        """
        _band = self._handle.GetRasterBand(1)
        sys.stderr.write('Loading data from {0}...\n'.format(self._filepath))
        
        self.data = _band.ReadAsArray(0, 0, self.width, self.height)
        if self.data is None:
            raise IOError('Failed to load data from {0}'.format(self._filepath))
        
        sys.stderr.write('DONE Loading data from {0}...\n'.format(self._filepath))



def main():
    """ 
    Read GRUMP population and urban-extent data into text file
    for import into DB
    """

    urban = RasterFile(_urbanFile)
    pop = RasterFile(_popFile)
    
    pop.loadData()
    urban.loadData()
   
    
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
    
    for xOffset in range(startx,urban.width):
    
        lon = ((xOffset+0.5) * urban.pixelWidth) + urban.xOrigin
    
        popX = int((lon - pop.xOrigin) / pop.pixelWidth)
    
        # 
        # The urban extent and population rasters are not the same size
        # avoid walking off the edge
        #
        if popX >= pop.width:
            sys.stderr.write('INFO no population values for x={0} lon={1}, skipping\n'.format(xOffset,lon))
            skippedCells += urban.height
            continue
    
        for yOffset in range(starty,urban.height):
            lat = ((yOffset+0.5) * urban.pixelHeight) + urban.yOrigin
    
            urValue = urban.data[yOffset, xOffset]
            popY = int((lat - pop.yOrigin) / pop.pixelHeight)
    
            if popY >= pop.height:
                sys.stderr.write(
    				'INFO no population values for x={0},y={1} urValue={2}\n'.format(
    				xOffset,yOffset,urValue))
                skippedCells += urban.height-yOffset
                continue
    
    #		sys.stderr.write(
    #			'DEBUG population values for x={0},y={1} lat={2},lon={3}, popX={4},popY={5}\n'.format(
    #			xOffset,yOffset,lat,lon,popX,popY))
    
            popValue = pop.data[popY, popX]
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
    totalCells = (urban.width-startx) * urban.height 
    expectedCells = totalCells - skippedCells
    waterAndLandCells=waterCells+landCells
    urnSum=urbanCells+ruralCells+nullCells
    
    sys.stderr.write(
    	'DONE total cells={0}x{1} = {2} skipped={3} read={4} expected={5}\n'.format(
    	(urban.width-startx),urban.height,totalCells,skippedCells,totalRead,expectedCells))
    
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

#
# Main driver
#
if __name__ == "__main__":
    main()
