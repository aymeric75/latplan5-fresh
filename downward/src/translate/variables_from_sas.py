#!/usr/bin/env python
import re
import sys
import re

START_PATTERN = '^begin_variable$'
END_PATTERN = '^end_variable$'


with open(sys.argv[1]) as file:

    newfile = open(sys.argv[2]+".txt", 'w')
    arrayy = []
    tmp_array = []
    between = False
    take_into_account=False

    cc=0

    printed_out=False

    for line in file:

        if re.match(START_PATTERN, line):
            cc=0
            take_into_account = False
            tmp_array = []
            between = True
            continue
        elif re.match(END_PATTERN, line):
            between = False
            arrayy.append(tmp_array)
            if take_into_account==True:
                newfile.write("#")
                newfile.write("\n")
            cc=0
            continue
        else:
            if(between == True):
                if(cc==2):
                    if int(line) > 2:
                        take_into_account=True
                
                if(cc>2 and take_into_account):
                    thenumber = re.findall(r'\d+', line)
                    if len(thenumber) > 0:
                        newfile.write(str(int(thenumber[0])))
                        newfile.write("\n")
                        if not printed_out:
                            print("VARIABLES WERE FOUND !!")
                            printed_out=True
                    if "none of those" in line:
                        newfile.write("NoneOfThose")
                        newfile.write("\n")  
                cc+=1
    # if take_into_account == True:
    #        print("VARIABLES WERE FOUND !!")
    
    newfile.close()

file.close()