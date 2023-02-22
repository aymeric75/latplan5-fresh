#!/bin/bash
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --partition=g100_usr_interactive
#SBATCH --account=uBS23_InfGer
#SBATCH --time=05:00:00
#SBATCH --mem=64G
## SBATCH --ntasks-per-socket=1


## PUZZLE MNIST
#SBATCH --error=myJobMeta_mnist_without_052.err
#SBATCH --output=myJobMeta_mnist_without_052.out
task="puzzle"
type="mnist"
width_height="3 3"
nb_examples="5000"
#suffix="with" # = with author's weight, no noisy test init/goal
suffix="without" # = without author's weight, no noisy test init/goal
# suffix="noisywith"
# suffix="noisywithout"
baselabel="mnist_"$suffix
after_sample="puzzle_mnist_3_3_5000_CubeSpaceAE_AMA4Conv_kltune2"
pb_subdir="puzzle-mnist-3-3"

conf_folder="05-06T11:21:55.052"
#conf_folder=05-06T11:21:55.052WITHBOTH
#conf_folder=05-06T11:21:55.052WITHVARS

pwdd=$(pwd)
#label=${baselabel}_${conf_folder: -3}
label=mnist_without_052
#label=mnist_without_052WITHVARS
#label=mnist_without_052WITHBOTH
problem_file="ama3_samples_${after_sample}_logs_${conf_folder}_domain_blind_problem.pddl"
problems_dir=problem-generators/backup-propositional/vanilla/$pb_subdir
domain_dir=samples/$after_sample/logs/$conf_folder
domain_file=$domain_dir/domain.pddl

loadweights="False"
nbepochs="2001"
numstep="2"
moduloepoch="400"



###    label=${baselabel}_${conf_folder: -3}
###    where baselabel (type_without_NumOfConfigRep)

## Function that
## 1: output the "normal" perfs (metrics) in the config directory
## 2: output the planning perfs (also in the config dir, same file)
test_function() {

    # 1
    ./train_kltune.py report $task $type $width_height $nb_examples CubeSpaceAE_AMA4Conv kltune2 --hash $conf_folder --label $label

    # 2
    nbsolSeven=0
    nboptsolSeven=0
    nbsolFourteen=0
    nboptsolFourteen=0

    

    for dir_prob in $problems_dir/*/
    do
        current_problems_dir=${dir_prob%*/}
        OUTPUT=$(python downward/fast-downward.py $pwdd/$domain_file $pwdd/$current_problems_dir/$problem_file --search "astar(blind())")
        if [[ "$(basename $dir_prob)" == *"7"* ]];then
            if [[ $OUTPUT == *"] Solution found!"* ]]; then
                echo "solution found, incrementing nbsolSeven"
                nbsolSeven=$((nbsolSeven+1))
            fi
            if [[ $OUTPUT == *"Plan length: 7 step(s)"* ]]; then
                echo "Optimal solution found, incrementing nboptsolSeven"
                nboptsolSeven=$((nboptsolSeven+1))
            fi
        fi
        if [[ "$(basename $dir_prob)" == *"14"* ]];then
            if [[ $OUTPUT == *"] Solution found!"* ]]; then
                echo "solution found, incrementing nbsolFourteen"
                nbsolFourteen=$((nbsolFourteen+1))
            fi
            if [[ $OUTPUT == *"Plan length: 14 step(s)"* ]]; then
                echo "Optimal solution found, incrementing nboptsolFourteen"
                nboptsolFourteen=$((nboptsolFourteen+1))
            fi
        fi
    done
    
    echo "nbsolSeven $nbsolSeven" >> $domain_dir/perfs_$label
    echo "nboptsolSeven $nboptsolSeven" >> $domain_dir/perfs_$label
    echo "nbsolFourteen $nbsolFourteen" >> $domain_dir/perfs_$label
    echo "nboptsolFourteen $nboptsolFourteen" >> $domain_dir/perfs_$label
}


# (reformat "slightly")
generate_and_reformat_domain() {

    

    # generate csvs
    ./train_kltune.py dump $task $type $width_height $nb_examples CubeSpaceAE_AMA4Conv kltune2 --hash $conf_folder --lab_weights $lab_weights

    # generate domain.pddl
    ./pddl-ama3.sh $pwdd/$domain_dir
    
    # reformat domain.pddl
    sed -i 's/+/plus/' $pwdd/$domain_file
    sed -i 's/-/moins/' $pwdd/$domain_file
    sed -i 's/negativemoinspreconditions/negative-preconditions/' $pwdd/$domain_file

}


reformat_domain_last() {
    cd ./downward/src/translate
    python main.py $pwdd/$domain_file $pwdd/$current_problems_dir/$problem_file --operation='remove_duplicates'
    cd $pwdd
}

generate_problems() {
    echo "AA2 "
    ./ama3-planner-all.py $domain_file $current_problems_dir blind 1 "None" ""
    echo "AA3 "
}


reformat_problem() {
    cd ./downward/src/translate

    python main.py $pwdd/$domain_file $pwdd/$current_problems_dir/$problem_file --operation='remove_not_from_prob'
    cd $pwdd
}

generate_sas() {

    cd $pwdd/downward/src/translate/
    ### Generate SAS file
    OUTPUT=$(python translate.py $pwdd/$domain_file $pwdd/$current_problems_dir/$problem_file --sas-file output_$label.sas)
    cd $pwdd

}




# "1" simple training
if [ $numstep -eq "1" ]; then
    ./train_kltune.py learn $task $type $width_height $nb_examples CubeSpaceAE_AMA4Conv kltune2 --hash $conf_folder --loadweights $loadweights --nbepochs $nbepochs
    exit 0
fi

# "2" generate domain and problems
if [ $numstep -eq "2" ]; then

    # 1) generate and reformat domain
    lab_weights="1_1600"

    generate_and_reformat_domain
    current_problems_dir=$problems_dir

    # 2) generate_and_reformat_problem s
    cd $pwdd
    ./clean-problems.sh
    cd $pwdd
    generate_problems

    # 3) reformat domain last
    for dir_prob in $problems_dir/*/
    do
        current_problems_dir=${dir_prob%*/}
        reformat_domain_last
        break
    done

    

    # # 4) reformat problems
    # for dir_prob in $problems_dir/*/
    # do
    #     current_problems_dir=${dir_prob%*/}
    #     reformat_problem
    # done

fi


# "3" invariants generation
## = generation du sas PUIS, une fois bon sas generé, génération du fichier d'invariants (à placer à la racine ?)
if [ $numstep -eq "3" ]; then
    generate_sas_plus_mutexes
    exit 0
fi

# "4" testing = call test_function for each invariant, and Also specify the number of atoms involved
## 'test_function' must also takes an 'index' parameter that indicates the index of the mutex in the .txt file
if [ $numstep -eq "4" ]; then

    

    echo "start new training" > $pwdd/$domain_dir/val_metrics_$label.txt

    echo "planning perfs" > $pwdd/$domain_dir/val_perfs_$label.txt

    for i in {1..3}
    do
        echo "start ROUND : $i, writting perfs metrics..." >> $pwdd/$domain_dir/val_metrics_$label.txt

        # ### TRAINING AND (normal) PERF
        invindex=0
        ./train_kltune.py learn $task $type $width_height $nb_examples CubeSpaceAE_AMA4Conv kltune2 --hash $conf_folder --label $label --loadweights $loadweights --nbepochs $nbepochs --invindex $invindex --round_number $i --moduloepoch $moduloepoch
    
        continue


    done

fi



if [ $numstep -eq "5" ]; then



    echo "planning perfs" > $pwdd/$domain_dir/val_perfs_$label.txt

    # for each seed
    for i in {1..3}
    do
        # for each epoch number
        #   parameters["moduloepoch"] must be the step

        echo "Training with seed $i" >> $pwdd/$domain_dir/val_perfs_$label.txt
            
        for epoch in {0..2000..200}
        do
            # qu'est ce que tu fais là ?
            #   ==> 
            # clean all problemes files
            ./clean-problems.sh

            # pour chaque poids, generate new domain.pddl (et reformat) et generate all problems (et pas de reformat)
            generate_and_reformat_domain

            # generate all the problems
            current_problems_dir=$problems_dir
            generate_problems

            # final reformatting of the domain.pddl
            for dir_prob in $problems_dir/*/
            do
                current_problems_dir=${dir_prob%*/}
                reformat_domain_last
                break
            done


            # pour chaque domain.pddl et new problems generated, reparcourir problems

            counter_solSeven=0 # #solutions for the 7's size pbs
            counter_optSeven=0 # #OptSolutions for the 7's size pbs
            counter_solFourteen=0 # #solutions for the 14's size pbs
            counter_optFourteen=0 # #OptSolutions for the 14's size pbs

            total_nb_variables_generated=0
            total_nb_mutexes_generated=0
            counter_gen_vars=0
            counter_gen_mutex=0

            for dir_prob in $problems_dir/*/
            do

                ### USE THE PDDL FILES to check for plan solutions
                ###

                current_problems_dir=${dir_prob%*/}

                # if a 7 step prob
                OUTPUT=$(python downward/fast-downward.py $pwdd/$domain_file $pwdd/$current_problems_dir/$problem_file --search "astar(blind())")
                echo $OUTPUT
                if [[ "$(basename $dir_prob)" == *"7"* ]];then
                    echo "here 1"
                    if [[ $OUTPUT == *"] Solution found!"* ]]; then
                        counter_solSeven=$((counter_solSeven+1))
                    fi
                    if [[ $OUTPUT == *"Plan length: 7 step(s)"* ]]; then
                        counter_optSeven=$((counter_optSeven+1))
                    fi
                fi

                # if a 14 step prob
                OUTPUT=$(python downward/fast-downward.py $pwdd/$domain_file $pwdd/$current_problems_dir/$problem_file --search "astar(blind())")
                if [[ "$(basename $dir_prob)" == *"14"* ]];then
                    if [[ $OUTPUT == *"] Solution found!"* ]]; then
                        counter_solFourteen=$((counter_solFourteen+1))
                    fi
                    if [[ $OUTPUT == *"Plan length: 14 step(s)"* ]]; then
                        counter_optFourteen=$((counter_optFourteen+1))
                    fi
                fi


                ### REGENERATE A SAS corresponding to current domain.pddl + problem.pddl
                ###

                cd $pwdd/downward/src/translate/
                ### Generate SAS file
                OUTPUT=$(python translate.py $pwdd/$domain_file $pwdd/$current_problems_dir/$problem_file --sas-file output_$label.sas)

                numb_vars=$(echo $OUTPUT | grep "Translator variables:" | grep -Eo '[0-9]{1,4}')

                numb_mutex=$(echo $OUTPUT | grep "Translator mutex groups:" | grep -Eo '[0-9]{1,4}')

                re='^[0-9]+$'
                if [[ $numb_vars =~ $re ]] ; then
                    total_nb_variables_generated=$((total_nb_variables_generated+$numb_vars))
                    counter_gen_vars=$((counter_gen_vars+1))
                fi
                if [[ $numb_mutex =~ $re ]] ; then
                    total_nb_mutexes_generated=$((total_nb_mutexes_generated+$numb_mutex))
                    counter_gen_mutex=$((counter_gen_mutex+1))
                fi


                cd $pwdd

            done


            mean_nb_variables_generated=$((total_nb_variables_generated / counter_gen_vars))
            mean_nb_mutexes_generated=$((total_nb_mutexes_generated / counter_gen_mutex))

            echo "round $i, epoch $j : counter_solSeven $counter_solSeven counter_optSeven $counter_optSeven counter_solFourteen $counter_solFourteen counter_optFourteen $counter_optFourteen mean_nb_variables_generated $mean_nb_variables_generated mean_nb_mutexes_generated $mean_nb_mutexes_generated" >> $pwdd/$domain_dir/val_perfs.txt


        done


    done


fi