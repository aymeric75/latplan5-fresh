#!/usr/bin/env python3
import sys


# expect a file like
# #
# 92 0
# 91 1
# ETC.
def return_invariant_list(file):
    retour = []
    with open(file) as f:
        total_string = ",".join(line.strip() for line in f)
        arr_of_invariants = total_string.split("#")
        for inv in arr_of_invariants:
            arr_of_vars = inv.split(",")
            #print(arr_of_vars)
            inv_arr = list(filter(None, arr_of_vars))
            # if inv_var not empty
            if inv_arr:
                retour.append(inv_arr)
        return retour

#def construct_inv_file(liste):

def remove_duplicates(new_liste):
    # remove obvious duplicates
    # new_liste = list(dict.fromkeys(liste))
    last_list = []
    for i in range(len(new_liste)):
        has_duplicate = False
        for j in range(i+1, len(new_liste)):
            if (new_liste[i][0] in new_liste[j] and new_liste[i][1] in new_liste[j]):
                has_duplicate = True
        if not has_duplicate:
            last_list.append(new_liste[i])
    
    return last_list

def construct_inv_file(liste, file):

    with open(file, "w") as f:

        for ele in liste:
            f.write("#\n")
            f.write(ele[0]+"\n")
            f.write(ele[1]+"\n")



def main():
    # 
    base_liste = return_invariant_list(sys.argv[1])
    clean_list = remove_duplicates(base_liste)

    print(len(clean_list))

if __name__ == '__main__':
    main()

