#!/usr/bin/env python3

import math
import matplotlib.pyplot as plt
import matplotlib
import sys
sys.path.append("../../../lib/open-logic/3rdParty/en_cl_fix/bittrue/models/python")
from en_cl_fix_pkg import *

class SinLut:

    def __init__(self, DataWidth_g, LutWidth_g):
        assert DataWidth_g >= 2, "DataWidth_g must be greater than 2"
        self.DataWidth_g = DataWidth_g
        self.LutWidth_g = max(min(LutWidth_g, DataWidth_g-2), 0)
        self.LutSize_c = 2**self.LutWidth_g
        self.Sin_c = []
        self.Cos_c = []
        for i in range (0, self.LutSize_c):
            self.Sin_c.append(math.sin(i*2*math.pi/(4*self.LutSize_c)))
            self.Cos_c.append(math.cos(i*2*math.pi/(4*self.LutSize_c)))

    @staticmethod
    def _slice(value, upper, lower):
        return value >> lower & 2**(upper-lower+1)-1
    
    @staticmethod
    def _bit(value, bit):
        return value >> bit & 0x1
    
    def _lookup(self, angle : int) -> tuple[float, float]:
        quadrant = self._slice(angle, self.DataWidth_g-1, self.DataWidth_g-2)
        lutIndex = self._slice(angle, self.DataWidth_g-3, self.DataWidth_g-3-self.LutWidth_g+1)
        case = quadrant 
        match case:
            case 0:
                sinValue = self.Sin_c[lutIndex]
                cosValue = self.Cos_c[lutIndex]
            case 1:
                sinValue = self.Cos_c[lutIndex]
                cosValue = -self.Sin_c[lutIndex]
            case 2:
                sinValue = -self.Sin_c[lutIndex]
                cosValue = -self.Cos_c[lutIndex]
            case 3:
                sinValue = -self.Cos_c[lutIndex]
                cosValue = self.Sin_c[lutIndex]
        return (sinValue, cosValue)
    
    def _lookupNext(self, angle : int) -> tuple[float, float]:
        nextAngle = angle + (1 << self.DataWidth_g-3-self.LutWidth_g + 1)
        return self._lookup(nextAngle)
    
    
    def Read(self, angle : int) -> tuple[float, float]:
        sinLutValue, cosLutValue = self._lookup(angle)
        sinLutNextValue, cosLutNextValue = self._lookupNext(angle)
        sinSegment = sinLutNextValue - sinLutValue
        cosSegment = cosLutNextValue - cosLutValue
        linearScale = self._slice(angle, self.DataWidth_g-3-self.LutWidth_g, 0) / 2**(self.DataWidth_g-2-self.LutWidth_g)
        sinValue = sinLutValue + (sinSegment * linearScale)
        cosValue = cosLutValue + (cosSegment * linearScale)
        return (sinValue, cosValue)

if __name__ == "__main__":

    DataWidth_g = 12
    LutWidth_g = 4

    FixFormat_c = FixFormat(True, 0, DataWidth_g-1)
    
    sinLut = SinLut(DataWidth_g, LutWidth_g)

    sinTable, cosTable = [], []
    for i in range(0, 2**DataWidth_g):
        sinValue, cosValue = sinLut.Read(i)
        sinTable.append(sinValue)
        cosTable.append(cosValue)

    plt.plot(sinTable, 'o')
    plt.plot(cosTable, 'o')
    plt.grid()
    plt.show()



