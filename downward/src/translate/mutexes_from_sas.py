#!/usr/bin/env python
import re
import sys

START_PATTERN = '^begin_variable$'
END_PATTERN = '^end_variable$'



dict_vars={}
with open(sys.argv[1]) as file:


    # First : create the array of the variables
    # where each index <=> to a variable

    cc=0 # counter for within the variable
    between = False
    
    tmp_array=[]
    #counter_var=0
    key=0

    for line in file:


        if re.match(START_PATTERN, line):
            cc=0
            tmp_array = []
            between = True
            continue
        elif re.match(END_PATTERN, line):
            between = False
            if(len(tmp_array)>0):
                dict_vars[key] = tmp_array
            cc=0
            continue
        else:
            if(between == True):

                if(cc==0):
                    
                    thenumber = re.findall(r'\d+', line)
                    key=int(thenumber[0])
                    
                if(cc>2):
                    thenumber = re.findall(r'\d+', line)
                    if len(thenumber) > 0:
                        tmp_array.append(str(int(thenumber[0])))
                    if "none of those" in line:
                        tmp_array.append("NoneOfThose")
                cc+=1

    print(dict_vars)

file.close()

exit()

START_PATTERN = '^begin_mutex_group$'
END_PATTERN = '^end_mutex_group$'

arr_mutexes=[]
with open(sys.argv[1]) as file:


    cc=0 # counter for within the variable
    between = False
    tmp_array=[]
    key=0


    jj=0
    for line in file:

        if(jj>1600):
            break

        if re.match(START_PATTERN, line):
            cc=0
            tmp_array = []
            between = True
            continue
        elif re.match(END_PATTERN, line):
            between = False
            if(len(tmp_array)>0):
                arr_mutexes.append(tmp_array)
            cc=0
            continue
        else:
            if(between == True):

                if(cc>0):

                    #print(line)

                    var_number, value_index  = line.split(" ")
                    
                    print(int(value_index))
                    z_index = dict_vars[int(var_number)][int(value_index)]

                    if "none of those" in str(z_index):
                        print("NONE in a MUTEX !!!!!!!!!!!!!")
                        exit()
                    else:
                        tmp_array.append(z_index)

                  
                cc+=1

        jj+=1


file.close()

print(arr_mutexes)
