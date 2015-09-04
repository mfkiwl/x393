from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2015, Elphel.inc.
# Class to set memory controller channels  
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
@contact:    andrey@elphel.coml
@deffield    updated: Updated
'''
__author__ = "Andrey Filippov"
__copyright__ = "Copyright 2015, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Andrey Filippov"
__email__ = "andrey@elphel.com"
__status__ = "Development"
#import sys
#import pickle
#from x393_mem                import X393Mem
#import x393_axi_control_status

#import x393_utils

#import time
import vrlg

def func_encode_mode_scan_tiled   (disable_need = False,
                                   repetitive=    True,
                                   single =       False,
                                   reset_frame =  False,
                                   byte32 =       True,
                                   keep_open =    False,
                                   extra_pages =  0,
                                   write_mem =    False,
                                   enable =       True,
                                   chn_reset =    False):
    """
    Combines arguments to create a 12-bit encoded data for scanline mode memory R/W
    @param disable_need - disable 'need' generation, only 'want' (compressor channels),
    @param repetitive   - run repetitive frames (add this to older 'master' tests)
    @param single       - run single frame
    @param reset_frame  - reset frame number
    @param byte32 -       32-byte columns (False - 16-byte columns) (not used in scanline mode)
    @param keep_open-     for 8 or less rows - do not close page between accesses (not used in scanline mode)
    @param extra_pages  2-bit number of extra pages that need to stay (not to be overwritten) in the buffer
                    This argument can be used for  read access with horizontal overlapping tiles
    @param write_mem,    write to memory mode (0 - read from memory)
    @param enable,       enable requests from this channel ( 0 will let current to finish, but not raise want/need)
    @param chn_reset):   immediately reset all the internal circuitry
    
    """
    rslt = 0;
    rslt |= (1,0)[chn_reset] <<    vrlg.MCONTR_LINTILE_EN # inverted
    rslt |= (0,1)[enable] <<       vrlg.MCONTR_LINTILE_NRESET
    rslt |= (0,1)[write_mem] <<    vrlg.MCONTR_LINTILE_WRITE
    rslt |= (extra_pages & ((1 <<  vrlg.MCONTR_LINTILE_EXTRAPG_BITS) - 1)) << vrlg.MCONTR_LINTILE_EXTRAPG
    rslt |= (0,1)[keep_open] <<    vrlg.MCONTR_LINTILE_KEEP_OPEN
    rslt |= (0,1)[byte32] <<       vrlg.MCONTR_LINTILE_BYTE32
    rslt |= (0,1)[reset_frame] <<  vrlg.MCONTR_LINTILE_RST_FRAME
    
    rslt |= (0,1)[single] <<       vrlg.MCONTR_LINTILE_SINGLE
    rslt |= (0,1)[repetitive] <<   vrlg.MCONTR_LINTILE_REPEAT
    rslt |= (0,1)[disable_need] << vrlg.MCONTR_LINTILE_DIS_NEED
    return rslt

'''
class X393Mcntrl(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
    x393_mem=None
    x393_axi_tasks=None #x393X393AxiControlStatus
    x393_utils=None
    verbose=1
    def __init__(self, debug_mode=1,dry_mode=True, saveFileName=None):
        self.DEBUG_MODE=  debug_mode
        self.DRY_MODE=    dry_mode
        self.x393_mem=            X393Mem(debug_mode,dry_mode)
        self.x393_axi_tasks=      x393_axi_control_status.X393AxiControlStatus(debug_mode,dry_mode)
        self.x393_utils=          x393_utils.X393Utils(debug_mode,dry_mode, saveFileName) # should not overwrite save file path
        try:
            self.verbose=vrlg.VERBOSE
        except:
            pass
 '''       