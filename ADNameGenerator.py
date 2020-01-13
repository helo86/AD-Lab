#!/usr/bin/env python3
"""
AD Name Generator:
Vname + NName and Vname + . + NName
Nname + VName and Nname + . + VName

Robert Gordon
Examples:
rogordon
rogordo
rogord
rgordon
rgordo
rgord
ro.gordon
ro.gordo
r.gordon
r.gordo
"""

vname  = input("Enter Name: ")
nname  = input("Enter Surname: ")

vnameLen = len (vname)
nnameLen = len (nname)

for x in range(vnameLen):
    print(vname[0:x+1])

for y in range(nnameLen):
    print(nname[0:nnameLen-y])

for x in range(vnameLen):
    for y in range(nnameLen):
        print(vname[0:x+1]+nname[0:nnameLen-y])

for x in range(nnameLen):
    for y in range(vnameLen):
        print(nname[0:x+1]+vname[0:nnameLen-y])

for x in range(vnameLen):
    for y in range(nnameLen):
        print(vname[0:x+1]+"."+nname[0:nnameLen-y])

for x in range(nnameLen):
    for y in range(vnameLen):
        print(nname[0:x+1]+"."+vname[0:nnameLen-y])
