#!/bin/bash


cd problem-generators/backup-propositional/

shopt -s extglob

for dir in vanilla/*/
do
    current_dir=${dir%*/}
    echo $current_dir


    cd $current_dir

    #pwd
    ls


    for subdir in */
    do
        echo $subdir
        
        cd $subdir
        
        #ls
        #rm !(goal.png|init.png) 
        find . -type f -not -name '*.png' -delete
        find . -type f -name 'ama3*' -delete
        #rm 'ama3*'

        cd ..

    done

    cd ..


done

shopt -u extglob