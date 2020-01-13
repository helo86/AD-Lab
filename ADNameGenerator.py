#!/usr/bin/env python3
"""
AD Name Generator:
rogordon
rogordo
rogord
rgordon
rgordo
rgord
"""

vname = "robert"
nname = "gordon"

vnameLen = len (vname)
nnameLen = len (nname)

for x in range(vnameLen):
    print(vname[0:x+1])

for y in range(nnameLen):
    print(nname[0:nnameLen-y])

for x in range(vnameLen):
    for y in range(nnameLen):
        print(vname[0:x+1]+nname[0:nnameLen-y])
