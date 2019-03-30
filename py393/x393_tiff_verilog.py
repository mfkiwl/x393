from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2015, Elphel.inc.
# Class to export hardware definitions from Verilog parameters  
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http:#www.gnu.org/licenses/>.

@author:     Andrey Filippov
@copyright:  2015 Elphel, Inc.
@license:    GPLv3.0+
@contact:    andrey@elphel.com
@deffield    updated: Updated
'''
__author__ = "Andrey Filippov"
__copyright__ = "Copyright 2015, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Andrey Filippov"
__email__ = "andrey@elphel.com"
__status__ = "Development"
 
from PIL import Image
import sys
import numpy as np

try:
  fname = sys.argv[1]
except IndexError:
  fname = "/data_ssd/nc393/elphel393/fpga-elphel/x393/attic/hor-pairs-12b-1044x36.tiff"

try:
  digits = int(sys.argv[2])
except:
  digits = 3
try:
  outname = sys.argv[3]
except IndexError:
  outname = fname.replace(".tiff",".vh")  

tif = Image.open(fname)

image_array = np.array(tif)

f="%%0%dx"%(digits)
with open(outname,"w") as outfile:
    print("//",file=outfile)
    print("// autogenerated from %s"%(fname),file=outfile)
    print("//",file=outfile)
    for image_line in image_array:
        for pixel in image_line:
            print(f%(pixel), file=outfile, end = " ")
        print(file=outfile)
tif.close()

print ("All done!")

