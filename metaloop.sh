#!/bin/bash
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --partition=g100_usr_interactive
#SBATCH --account=uBS23_InfGer
#SBATCH --time=00:30:00
#SBATCH --mem=64G
#SBATCH --ntasks-per-socket=1



# # SOKOBAN
# #SBATCH --error=myJobMeta_sokoban_without_551.err
# #SBATCH --output=myJobMeta_sokoban_without_551.out
# task="sokoban"
# type="sokoban_image-20000-global-global-2-train"
# width_height=""
# nb_examples="20000"
# #suffix="with"
# suffix="without"
# # suffix="noisywith"
# # suffix="noisywithout"
# baselabel="sokoban"
# after_sample="sokoban_sokoban_image-20000-global-global-2-train_20000_CubeSpaceAE_AMA4Conv_kltune2"
# pb_subdir="sokoban-2-False"




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



pwdd=$(pwd)

conf_folder="05-06T11:21:55.052"
loadweights="True"
nbepochs="2000"
numstep="3"




############################################
##              Functions                 ##
############################################

# from extracted_mutexes_*.txt to current_invariant.txt (in root)
extract_current_invariant() {
    echo "#" > current_invariant_$label.txt
    sed -n '2p' extracted_mutexes_$label.txt >> current_invariant_$label.txt
    sed -n '3p' extracted_mutexes_$label.txt >> current_invariant_$label.txt
}

# remove current invariant from total_invariants_*.txt (in root)
remove_current_invariant() {
    sed -i '1,3d' $pwdd/extracted_mutexes_$label.txt
}


#  store metrics in bash variables
produce_report() {

    ./train_kltune.py report $task $type $width_height $nb_examples CubeSpaceAE_AMA4Conv kltune2 --hash $rep_model --label $label
    
    current_state_var=$(sed '1q;d' $pwdd/$path_to_repertoire/variance_$label.txt)
    current_elbo=$(sed '2q;d' $pwdd/$path_to_repertoire/variance_$label.txt)
    current_next_state_pred=$(sed '3q;d' $pwdd/$path_to_repertoire/variance_$label.txt)
    current_true_num_actions=$(sed '4q;d' $pwdd/$path_to_repertoire/variance_$label.txt)
}

# write metrics in omega_*.txt
write_to_omega() {
    echo "state_var: $current_state_var" >> omega_$label.txt
    echo "elbo: $current_elbo" >> omega_$label.txt
    echo "next_state_pred: $current_next_state_pred" >> omega_$label.txt
    echo "num_actions: $current_true_num_actions" >> omega_$label.txt
    echo " " >> omega_$label.txt
}


domain_pddl_to_bak_without () {
    cp $domain $domain_bak_without
}

domain_pddl_from_bak_without () {
    cp $domain_bak_without $domain
}

domain_pddl_to_bak_with () {
    cp $domain $domain_bak_with
}

domain_pddl_from_bak_with () {
    cp $domain_bak_with $domain
}

### manage the "weights" files

weights_to_bak_without() {
    cp $weights $weights_without
}

weights_from_bak_without() {
    cp $weights_without $weights
}

weights_to_bak_with() {
    cp $weights $weights_with
}

weights_from_bak_with() {
    cp $weights_with $weights
}


### manage the "opt"

opt_to_bak_without() {
    cp $opt_file $opt_file_without
}

opt_from_bak_without() {
    cp $opt_file_without $opt_file
}



### manage the "p_a_zi_net.npz" files

p_a_zi_to_bak_with() {
    cp $p_a_z0_net $p_a_z0_net_with
    cp $p_a_z1_net $p_a_z1_net_with
}

p_a_zi_from_bak_with() {
    cp $p_a_z0_net_with $p_a_z0_net
    cp $p_a_z1_net_with $p_a_z1_net
}

p_a_zi_to_bak_without() {
    cp $p_a_z0_net $p_a_z0_net_without
    cp $p_a_z1_net $p_a_z1_net_without
}

p_a_zi_from_bak_without() {
    cp $p_a_z0_net_without $p_a_z0_net
    cp $p_a_z1_net_without $p_a_z1_net
}



test_if_solution_withinvs() {

    OUTPUT=$(python downward/fast-downward.py $pwdd/$domain $pwdd/$current_problems_dir/$problem_file --search "astar(blind())")
    echo $OUTPUT
    echo "Testing if planning solution (with invs)... " >> omega_$label.txt
    if [[ "$(basename $dir_prob)" == *"7"* ]];then
        if [[ $OUTPUT == *"] Solution found!"* ]]; then
            echo "solution found, incrementing nbsolsevenwithinvs" >> omega_$label.txt
            nbsolsevenwithinvs=$((nbsolsevenwithinvs+1))
        fi
        if [[ $OUTPUT == *"Plan length: 7 step(s)"* ]]; then
            echo "Optimal solution found, incrementing nboptimalsolsevenwithinvs" >> omega_$label.txt
            nboptimalsolsevenwithinvs=$((nboptimalsolsevenwithinvs+1))
        fi
    fi

    if [[ "$(basename $dir_prob)" == *"14"* ]];then
        if [[ $OUTPUT == *"] Solution found!"* ]]; then
            echo "solution found, incrementing nbsolfourteenwithinvs" >> omega_$label.txt
            nbsolfourteenwithinvs=$((nbsolfourteenwithinvs+1))
        fi
        if [[ $OUTPUT == *"Plan length: 14 step(s)"* ]]; then
            echo "Optimal solution found, incrementing nboptimalsolfourteenwithinvs" >> omega_$label.txt
            nboptimalsolfourteenwithinvs=$((nboptimalsolfourteenwithinvs+1))
        fi
    fi
}


test_if_solution_noinvs() {

    OUTPUT=$(python downward/fast-downward.py $pwdd/$domain $pwdd/$current_problems_dir/$problem_file --search "astar(blind())")
    echo $OUTPUT
    echo "Testing if planning solution (NO invs)... " >> omega_$label.txt
    if [[ "$(basename $dir_prob)" == *"7"* ]];then
        if [[ $OUTPUT == *"] Solution found!"* ]]; then
            echo "solution found, incrementing nbsolsevennoinvs " >> omega_$label.txt
            nbsolsevennoinvs=$((nbsolsevennoinvs+1))
        fi
        if [[ $OUTPUT == *"Plan length: 7 step(s)"* ]]; then
            echo "Optimal solution found, incrementing nboptimalsolsevennoinvs " >> omega_$label.txt
            nboptimalsolsevennoinvs=$((nboptimalsolsevennoinvs+1))
        fi
    fi


    if [[ "$(basename $dir_prob)" == *"14"* ]];then
        if [[ $OUTPUT == *"] Solution found!"* ]]; then
            echo "solution found, incrementing nbsolfourteennoinvs" >> omega_$label.txt
            nbsolfourteennoinvs=$((nbsolfourteennoinvs+1))
        fi
        if [[ $OUTPUT == *"Plan length: 14 step(s)"* ]]; then
            echo "Optimal solution found, incrementing nboptimalsolfourteennoinvs" >> omega_$label.txt
            nboptimalsolfourteennoinvs=$((nboptimalsolfourteennoinvs+1))
        fi
    fi

}


generate_actions_csv() {

    ./train_kltune.py dump $task $type $width_height $nb_examples CubeSpaceAE_AMA4Conv kltune2 --hash $rep_model
}

generate_domain_pddl() {
    ./pddl-ama3.sh $path_to_repertoire
}

generate_problem_pddl() {
    echo "domaindomaindomaindomain"
    echo $domain
    #
    
    ./ama3-planner.py $domain $current_problems_dir blind 1 "None" ""
}

reformat_domain_1() {
    echo $domain
    sed -i 's/+/plus/' $domain
    sed -i 's/-/moins/' $domain
    sed -i 's/negativemoinspreconditions/negative-preconditions/' $domain
    echo "remormated domain 1 done"
}

reformat_domain_2() {
    cd ./downward/src/translate
    python main.py $pwdd/$domain $pwdd/$current_problems_dir/$problem_file --operation='remove_duplicates'
    cd $pwdd
}

# rewrite: here reformat also domain...
reformat_problem() {
    cd ./downward/src/translate
    python main.py $pwdd/$domain $pwdd/$current_problems_dir/$problem_file --operation='remove_not_from_prob'
    cd $pwdd
}



# generate extracted_mutexes_* and put it in root
generate_invariants() {

    #generate_problem_pddl
    #reformat_domain_1
    #reformat_problem

    cd $pwdd/../h2-preprocessor/builds/release32/bin

    ### Generate a new SAS file FROM h2 preprocessor
    ./preprocess < $pwdd/downward/src/translate/output_$label_prob.sas --no_bw_h2


    mv output.sas output_$label_prob.sas

    ### Generate a files of mutex
    python ./retrieve_mutex.py output_$label_prob.sas $label_prob

    ### Copy the mutex file to the root dir
    cp extracted_mutexes_$label_prob.txt $pwdd/
    cd $pwdd/
}

generate_sas() {

    ###
    cd $pwdd/downward/src/translate/
    ### Generate SAS file
    python translate.py $pwdd/$domain $pwdd/$current_problems_dir/$problem_file --sas-file output_$label_prob.sas
    cd $pwdd
}


############################################
###########     END FUNCTIONS        #######
############################################








# loop over the configs
for dir_conf in samples/$after_sample/logs/*/
do

    rep_model=$(basename $dir_conf)
    domain=samples/$after_sample/logs/$rep_model/domain.pddl
    domain_bak_without=samples/$after_sample/logs/$rep_model/domain_bak_without.pddl
    domain_bak_with=samples/$after_sample/logs/$rep_model/domain_bak_with.pddl
    path_to_repertoire=samples/$after_sample/logs/$rep_model
    problem_file="ama3_samples_${after_sample}_logs_${rep_model}_domain_blind_problem.pddl"
    problem_file_bak="ama3_samples_${after_sample}_logs_${rep_model}_domain_blind_problem_bak.pddl"
    problems_dir=problem-generators/backup-propositional/vanilla/$pb_subdir

    weights=samples/$after_sample/logs/$rep_model/tmp/checkpoint/weights.h5
    weights_without=samples/$after_sample/logs/$rep_model/tmp/checkpoint/weights_without.h5
    weights_with=samples/$after_sample/logs/$rep_model/tmp/checkpoint/weights_with.h5

    p_a_z0_net=samples/$after_sample/logs/$rep_model/p_a_z0_net.npz
    p_a_z0_net_without=samples/$after_sample/logs/$rep_model/p_a_z0_net_without.npz
    p_a_z0_net_with=samples/$after_sample/logs/$rep_model/p_a_z0_net_with.npz

    p_a_z1_net=samples/$after_sample/logs/$rep_model/p_a_z1_net.npz
    p_a_z1_net_without=samples/$after_sample/logs/$rep_model/p_a_z1_net_without.npz
    p_a_z1_net_with=samples/$after_sample/logs/$rep_model/p_a_z1_net_with.npz


    opt_file=samples/$after_sample/logs/$rep_model/opt0.npz
    opt_file_without=samples/$after_sample/logs/$rep_model/opt0_without.npz

    label=${baselabel}_${rep_model: -3}


    #if [[ $rep_model != *"05-06T11:21:53.162"* ]] || [[ $rep_model != *"05-06T11:28:37.283"* ]]; then
    if [[ $rep_model != *$conf_folder* ]]; then
        continue
    fi


    if [ $numstep -eq "1" ]; then
        echo "Start" > omega_$label.txt
        # write the name of the config dir
        echo " " >> omega_$label.txt
        echo "Dir_conf: $rep_model " >> omega_$label.txt
    fi

    if [ $numstep -eq "2" ]; then
        echo "restart training (without invariants) " >> omega_$label.txt
    fi


    # ################################################################ #
    # # PHASE RETRAINING THE MODEL (without calling author's weights # #
    # ################################################################ #
   
    # No need to do anything with the weight files... we will not load them and then
    # we override them...
    # retrain the network ONCE
    # THEN go over the prob dirs (same as before, if find invs, test them THEN break)

    # we remove the invariants found from former trainings
    if [ $numstep -eq "1" ] || [ $numstep -eq "2" ] || [ $numstep -eq "3" ]; then
        rm invariants_to_test_$label.txt
    fi

    if [ $numstep -eq "1" ]; then
        echo "training without any invariant - round 1" >> omega_$label.txt
    fi

    if [ $numstep -eq "2" ]; then
        echo "training without any invariant - round 2" >> omega_$label.txt
    fi
    
    # fresh training (no invariants)
    if [ $numstep -eq "1" ] || [ $numstep -eq "2" ]; then
        ./train_kltune.py learn $task $type $width_height $nb_examples CubeSpaceAE_AMA4Conv kltune2 --hash $rep_model --loadweights $loadweights --nbepochs $nbepochs    
    
        exit 0

    fi

    if [ $numstep -eq "1" ]; then
        echo "(training without invariants : finished FIRST round, quitting)" >> omega_$label.txt


        # # backup the weights
        # weights_to_bak_without
        # p_a_zi_to_bak_without
        # opt_to_bak_without

        # produce and write perfs (but not the # of sol)
        produce_report
        echo "Performances after a first training (without invariants)" >> omega_$label.txt
        write_to_omega


        exit 0
    fi

    if [ $numstep -eq "2" ]; then
        echo "(training without invariants : finished SECOND round, backing up the WEIGHTS)" >> omega_$label.txt

        # backup the weights
        weights_to_bak_without
        p_a_zi_to_bak_without
        opt_to_bak_without

        # produce and write perfs (but not the # of sol)
        produce_report
        echo "Performances after a first training (without invariants)" >> omega_$label.txt
        write_to_omega
        exit 0
    fi


    ###############################
    #### PHASE TO FIND INVARIANTS #
    ###############################

    if [ $numstep -eq "3" ]; then

        found_invs=0

        echo "Now, looking for invariantss..." >> omega_$label.txt

        # regenerate domain (no need to use the backed ups for now..)
        #generate_actions_csv

        #exit 0
        
        # generate_domain_pddl
        # exit 0

        # reformat_domain_1
        # exit 0

        # reformat_domain_2
        # exit 0

        # same as above....
        #domain_pddl_to_bak_without


        for dir_prob in $problems_dir/*/
        do
            
            current_problems_dir=${dir_prob%*/} # Used in generate_invariants !

            # python downward/fast-downward.py $pwdd/$domain $pwdd/$current_problems_dir/$problem_file --search "astar(blind())"
            # exit 0

            # write the name of the prob dir
            echo "" >> omega_$label.txt
            echo "Dir_Prob: $(basename $dir_prob)" >> omega_$label.txt

            # # retrieve the domain.pddl from 1st training (ie without the invariants)
            # domain_pddl_from_bak_without

            # #retrieve weights without
            # weights_from_bak_without
            # p_a_zi_from_bak_without
            # opt_from_bak_without

            # regenerate problem
            # generate_problem_pddl
            # reformat_problem
            # reformat_domain_2
            #exit 0
            
            label_prob=$label$(basename $dir_prob)

            # try to generate invariants
            generate_sas
            exit 0

            # continue

            # generate_invariants
            # exit 0

            # nb_invariants_prob=$(./count_invariants.py $pwdd/extracted_mutexes_$label.txt)
            # if [ $nb_invariants_prob -gt 0 ]
            # then
            #     echo "Invariants found (NOT taking the author's released weights): " >> omega_$label.txt
            #     cat $pwdd/extracted_mutexes_$label.txt >> omega_$label.txt
            #     cat $pwdd/extracted_mutexes_$label.txt > invariants_to_test_$label.txt
            #     exit 0
            # fi

        done
    fi



    ##########################################
    #### PHASE TRAIN NETWORK WITH INVARIANTS #
    ##########################################

    if [ $numstep -eq "4" ] || [ $numstep -eq "5" ]; then

        if [ $numstep -eq "4" ]; then
            echo "Invariants were found (NOT taking the author's released weights)" >> omega_$label.txt
            echo "Re-training LatPlan with the found invariants - round 1" >> omega_$label.txt
        fi
        

        if [ $numstep -eq "5" ]; then
            echo "2nd training (with invariants): second round" >> omega_$label.txt
        fi

        ./train_kltune.py learn $task $type $width_height $nb_examples CubeSpaceAE_AMA4Conv kltune2 --hash $rep_model --label $label --loadweights $loadweights --nbepochs $nbepochs


        exit 0

        if [ $numstep -eq "4" ]; then
            echo "Finished 1st round of 2nd training, quitting..." >> omega_$label.txt
            exit 0
        fi

        if [ $numstep -eq "5" ]; then
            echo "Finished 2nd round of 2nd training (with invariants), backing up weights" >> omega_$label.txt
            weights_to_bak_with
            p_a_zi_to_bak_with
            # produce and write perfs (but not the # of sol)
            produce_report
            echo "Performances after the training with invariants" >> omega_$label.txt
            write_to_omega

            echo "Creating a new domain.pddl <=> invariants enforcing" >> omega_$label.txt
            # regenerate domain
            generate_actions_csv # use weights!
            generate_domain_pddl
            reformat_domain_1
            reformat_domain_2
            # make a backup of domain.pddl (to domain_bak_with.pddl)
            domain_pddl_to_bak_with 

            exit 0
        fi

    fi



    ######################################################################
    #### PHASE COUNTING THE SOLUTION FOR without and for with invariants #
    ######################################################################

    if [ $numstep -eq "6" ]; then

        # init variables for the # of solutions found
        nbsolsevenwithinvs=0
        nboptimalsolsevenwithinvs=0
        nbsolfourteenwithinvs=0
        nboptimalsolfourteenwithinvs=0

        nbsolsevennoinvs=0
        nboptimalsolsevennoinvs=0
        nbsolfourteennoinvs=0
        nboptimalsolfourteennoinvs=0


        for dir_prob in $problems_dir/*/
        do

            current_problems_dir=${dir_prob%*/} # Used in generate_invariants !

            # write the name of the prob dir
            echo "" >> omega_$label.txt
            echo "Dir_Prob: $(basename $dir_prob)" >> omega_$label.txt

            #### TEST without INVARIANTS

            # load pddl without
            domain_pddl_from_bak_without

            # retrieve weights without
            weights_from_bak_without
            p_a_zi_from_bak_without

            # regenerate problem
            generate_problem_pddl
            reformat_problem

            # test if some solution can be found
            test_if_solution_noinvs
            

            #### TEST with INVARIANTS

            # retrieve domain.pddl with
            domain_pddl_from_bak_with

            #retrieve weights with
            weights_from_bak_with
            p_a_zi_from_bak_with

            # regenerate problem
            generate_problem_pddl
            reformat_problem

            # Test domain+problem with fastdownward
            test_if_solution_withinvs

        done

        echo " " >> omega_$label.txt
        echo "#sol - no invs - 7steps: "$nbsolsevennoinvs >> omega_$label.txt
        echo "#sol - no invs - 14steps: "$nbsolfourteennoinvs >> omega_$label.txt
        echo "#sol - with invs - 7steps: "$nbsolsevenwithinvs >> omega_$label.txt
        echo "#sol - with invs - 14steps: "$nbsolfourteenwithinvs >> omega_$label.txt

        echo "#optimalsol - no invs - 7steps: "$nboptimalsolsevennoinvs >> omega_$label.txt
        echo "#optimalsol - no invs - 14steps: "$nboptimalsolfourteennoinvs >> omega_$label.txt
        echo "#optimalsol - with invs - 7steps: "$nboptimalsolsevenwithinvs >> omega_$label.txt
        echo "#optimalsol - with invs - 14steps: "$nboptimalsolfourteenwithinvs >> omega_$label.txt

    fi

done
