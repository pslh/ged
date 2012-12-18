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
# TODO convert to command line arguments
#
_urbanFile = '/data/ged/rebuild-pop/urban-rural/prj.adf'
_popFile = '/data/ged/rebuild-pop/pop-input/prj.adf'

class RasterFile(object):
    """
    Representation of a raster file
    """

    def _openFile(self, filepath):
        """
        Open the given file for reading, raise an IOError on failure.
        Note does not actually read the real data yes, see loadData
        """
        
        self._filepath=filepath
        #
        # Force use of float64 for population data
        # Note that this requires use of GDAL 1.9 (see env.sh)
        # See http://lists.osgeo.org/pipermail/gdal-dev/2006-July/009570.html
        #
        gdal.SetConfigOption('AAIGRID_DATATYPE', 'Float64')
        self._handle = gdal.Open(filepath, GA_ReadOnly) # Clear flag after open
        gdal.SetConfigOption('AAIGRID_DATATYPE', None)
        
        if self._handle is None:
            raise IOError("Failed to open file {0}\n".format(filepath));
 
    def _initMetaData(self):
        self.width = self._handle.RasterXSize
        self.height = self._handle.RasterYSize
        _transform = self._handle.GetGeoTransform()
        self.xOrigin = _transform[0]
        self.yOrigin = _transform[3]
        self.pixelWidth = _transform[1]
        self.pixelHeight = _transform[5]
        
    def __init__(self,filepath):
        self._openFile(filepath)
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

    def getLon(self,x):
        """
        The longitude corresponding to the given x (pixel) value
        """
        # Note + 0.5 to place point in centre of pixel
        return ((x+0.5) * self.pixelWidth) + self.xOrigin

    def getLat(self,y):
        """
        The latitude corresponding to the given y (pixel) value
        """
        # Note + 0.5 to place point in centre of pixel
        return ((y+0.5) * self.pixelHeight) + self.yOrigin

    def getX(self,lon):
        """
        The x (pixel) value for the given longitude
        """
        return int((lon - self.xOrigin) / self.pixelWidth)
        
    def getY(self,lat):
        """
        The y (line) value for the given latitude
        """
        return int((lat - self.yOrigin) / self.pixelHeight)


class _CellCountValidator(object):
    """
    Helper class to check that cell counts are self-consistent
    """
    
    def __init__(self, raster):
        self.raster=raster
        
        #
        # Counters for different types of cell
        # Used for validation later 
        #
        self.waterCells=0
        self.landCells=0
        self.skippedCells=0
        
        self.urbanCells=0
        self.ruralCells=0
        self.nullCells=0
        
        self.totalRead=0

    def validate(self, startx=0, starty=0):
        """    
        Validation checks - do our numbers add up?
        """
        
        totalCells = (self.raster.width - startx) * self.raster.height
        expectedCells = totalCells - self.skippedCells
        waterAndLandCells = self.waterCells + self.landCells
        urnSum = self.urbanCells + self.ruralCells + self.nullCells
        sys.stderr.write('DONE total cells='+
                         '{0}x{1} = {2} skipped={3} read={4} expected={5}\n'
                            .format(self.raster.width - startx, self.raster.height, 
                                    totalCells, self.skippedCells, self.totalRead,
                                    expectedCells))
        sys.stderr.write(' water={0}, land={1} sum={2}\n'
                            .format(self.waterCells, self.landCells, 
                                    waterAndLandCells))
        sys.stderr.write(' raster={0} rural={1} null={2} sum={3}\n'
                            .format(self.urbanCells, self.ruralCells, self.nullCells,
                                     urnSum))
        if self.totalRead != expectedCells:
            sys.stderr.write('WARNING cells read={0} != total-skipped={1}\n'
                                .format(self.totalRead, expectedCells))
        if totalCells != waterAndLandCells + self.skippedCells:
            sys.stderr.write('WARNING total cells={0} != land+water+skipped={1}\n'
                                .format(totalCells, waterAndLandCells + 
                                            self.skippedCells))
        if self.landCells != urnSum:
            sys.stderr.write('WARNING total land cells={0} != u+r+n={1}\n'
                                .format(self.landCells, urnSum))


def _extractData(urban, pop, validator, startx=0, starty=0):
    for x in range(startx,urban.width):
    
        lon = urban.getLon(x)
        popX = pop.getX(lon)
    
        # 
        # The urban extent and population rasters are not the same size
        # avoid walking off the edge
        #
        if popX >= pop.width:
            sys.stderr.write('INFO no population values for '+
                             'x={0} lon={1}, skipping\n'.format(x,lon))
            validator.skippedCells += urban.height
            continue
    
        for y in range(starty,urban.height):
            lat = urban.getLat(y)
            popY = pop.getY(lat)
    
            urValue = urban.data[y, x]
    
            if popY >= pop.height:
                sys.stderr.write(
                    'INFO no population values for x={0},y={1} urValue={2}\n'.format(
                    x,y,urValue))
                validator.skippedCells += urban.height-y
                continue
    
            popValue = pop.data[popY, popX]
            validator.totalRead += 1            
    
            isUrban=False
            if urValue == 1:
                isUrban = 'f'
                validator.ruralCells += 1
    
            elif urValue == 2:
                isUrban = 't'
                validator.urbanCells += 1
    
            elif urValue == 255:
                # no landCells mass
                if popValue == 0:
                    validator.waterCells += 1
                    continue
                else:
                    sys.stderr.write(
                        'WARNING NULL U/R values for x={0},y={1}, lat={2},lon={3}, pop={4}\n'.format(
                        x,y,lat,lon,popValue))
                    isUrban='\\N' # NULL SQL code
                    validator.nullCells += 1
            else:
                sys.stderr.write(
                    'ERROR Unnexpected U/R value {4} found at x={0},y={1}, lat={2},lon={3}\n'+
                    ' Check file format and GDAL version\n'.format(
                    x,y,lat,lon,urValue))
                sys.exit(1)
    
            print str(lat)+'\t'+str(lon)+'\t'+str(popValue)+'\t'+str(isUrban)
            validator.landCells += 1
            

def main():
    """ 
    Read GRUMP population and urban-extent data into text file
    for import into DB
    """

    urban = RasterFile(_urbanFile)
    pop = RasterFile(_popFile)

    # Use for end-game testing
    #_startx=urban.width-2#width-10 #30322 #22360
    # TODO make this a command line argument
    _startx=0;
    
    validator= _CellCountValidator(urban)

    urban.loadData()
    pop.loadData()
    
    _extractData(urban, pop, validator, _startx)

    # After loading data, check the validate cell counts
    validator.validate(_startx)

#
# Main driver
#
if __name__ == "__main__":
    main()
