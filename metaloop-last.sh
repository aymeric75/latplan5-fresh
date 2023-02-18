#!/bin/bash
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --partition=g100_usr_interactive
#SBATCH --account=uBS23_InfGer
#SBATCH --time=07:00:00
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

#conf_folder=05-06T11:21:55.052WITH
#conf_folder=05-06T11:21:55.052WITHOUT

pwdd=$(pwd)
label=${baselabel}_${conf_folder: -3}
#label=mnist_without_052
problem_file="ama3_samples_${after_sample}_logs_${conf_folder}_domain_blind_problem.pddl"
problems_dir=problem-generators/backup-propositional/vanilla/$pb_subdir
domain_dir=samples/$after_sample/logs/$conf_folder
domain_file=$domain_dir/domain.pddl

loadweights="True"
nbepochs="2000"
numstep="1"

nb_of_rounds=3


# ./generate-graphs.py $domain_dir/val_metrics.txt
# exit 0



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
    ./train_kltune.py dump $task $type $width_height $nb_examples CubeSpaceAE_AMA4Conv kltune2 --hash $conf_folder

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

generate_and_reformat_problem() {
    echo "AA2 "
    ./ama3-planner.py $pwdd/$domain_file $current_problems_dir blind 1 "None" ""
    echo "AA3 "
    cd ./downward/src/translate
    echo "AA4 "
    python main.py $pwdd/$domain_file $pwdd/$current_problems_dir/$problem_file --operation='remove_not_from_prob'
    echo "AA5 "
    cd $pwdd
    echo "AA6 "
    cd ./downward/src/translate
    echo "AA7 "
    python main.py $pwdd/$domain_file $pwdd/$current_problems_dir/$problem_file --operation='remove_not_from_prob'
    echo "AA8 "
    cd $pwdd
}


generate_sas_plus_mutexes() {


    for dir_prob in $problems_dir/*/
    do
        current_problems_dir=${dir_prob%*/}

        cd $pwdd/downward/src/translate/

        ### Generate SAS file
        python translate.py $pwdd/$domain_file $pwdd/$current_problems_dir/$problem_file --sas-file output_$label.sas

        OUTPUT=$(python variables_from_sas.py output_$label.sas found_variables_$label)
        echo "printing echo"
        echo $OUTPUT
        if [[ $OUTPUT == *"VARIABLES WERE FOUND !!"* ]]; then
            # found_variables_mnist_without_052
            mv found_variables_$label.txt $pwdd/$domain_dir/
            break
        fi
        cd $pwdd
    done
    cd $pwdd

}




# "1" simple training
if [ $numstep -eq "1" ]; then
    ./train_kltune.py learn $task $type $width_height $nb_examples CubeSpaceAE_AMA4Conv kltune2 --hash $conf_folder --loadweights $loadweights --nbepochs $nbepochs
    exit 0
fi

# "2" generate domain and problems
if [ $numstep -eq "2" ]; then

    generate_and_reformat_domain
    
    for dir_prob in $problems_dir/*/
    do
        echo "AA0 "
        current_problems_dir=${dir_prob%*/}
        # echo $current_problems_dir # problem-generators/backup-propositional/vanilla/puzzle-mnist-3-3/014-015
        echo "AA1 "
        generate_and_reformat_problem
        echo "AA "
        echo " "
    done

    #reformat_domain_last

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
    invindex=0
    ./train_kltune.py learn $task $type $width_height $nb_examples CubeSpaceAE_AMA4Conv kltune2 --hash $conf_folder --label $label --loadweights $loadweights --nbepochs $nbepochs --invindex $invindex --nb_of_rounds $nb_of_rounds
fi
