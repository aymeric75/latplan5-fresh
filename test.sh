#!/bin/bash

nbepochs=50

./clean-problems.sh

exit 0

for j in {0..50..10}
do
    # if [[ $j != 0 ]];then
    #     echo $j
    # fi
    echo "j : $j"
    for i in {0..50..10}
    do
        echo "i : $i"
        break
    done
done