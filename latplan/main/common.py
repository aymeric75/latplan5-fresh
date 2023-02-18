import os
import os.path
import glob

import numpy as np
import latplan.model
import latplan.util.stacktrace
from latplan.util.tuning import simple_genetic_search, parameters, nn_task, reproduce
from latplan.util        import curry

from numpy.random import seed


################################################################
# globals

args     = None
sae_path = None

################################################################
# command line parsing

import argparse

parser = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter)


# 
# RawDescriptionHelpFormatter
# ArgumentDefaultsHelpFormatter


parser.add_argument(
    "mode",
    help=(
        "A string which contains mode substrings."
        "\nRecognized modes are:"
        "\n" 
        "\n   learn     : perform the training with a hyperparameter tuner. Results are stored in logs/."
        "\n   plot      : load the weights of the current best hyperparameter and produce visualizations"
        "\n   dump      : dump csv files necessary for producing PDDL models"
        "\n   summary   : perform extensive evaluations and collect the statistics, store the result in performance.json"
        "\n   debug     : debug training limited to epoch=2, batch_size=100. dataset is truncated to 200 samples"
        "\n   reproduce : train the best hyperparameter so far three times with different random seeds. store the best results."
        "\n   iterate   : iterate plot/dump/summary commands above over all hyperparmeters that are already trained and stored in logs/ directory."
        "\n"
        "\nFor example, learn_plot_dump contains 'learn', 'plot', 'dump' mode."
        "\nThe separater does not matter because its presense is tested by python's `in` directive, i.e., `if 'learn' in mode:` ."
        "\nTherefore, learnplotdump also works."))


subparsers = parser.add_subparsers(
    title="subcommand",
    metavar="subcommand",
    required=True,
    description=(
        "\nA string which matches the name of one of the dataset functions in latplan.main module."
        "\n"
        "\nEach task has a different set of parameters, e.g.,"
        "\n'puzzle' has 'type', 'width', 'height' where 'type' should be one of 'mnist', 'spider', 'mandrill', 'lenna',"
        "\nwhile 'lightsout' has 'type' being either 'digital' and 'twisted', and 'size' being an integer."
        "\nSee subcommand help."))

def add_common_arguments(subparser,task,objs=False):
    subparser.set_defaults(task=task)
    subparser.add_argument(
        "num_examples",
        default=5000,
        type=int,
        help=(
            "\nNumber of data points to use. 90%% of this number is used for training, and 5%% each for validation and testing."
            "\nIt is assumed that the user has already generated a dataset archive in latplan/puzzles/,"
            "\nwhich contains a larger number of data points using the setup-dataset script provided in the root of the repository."))
    subparser.add_argument(
        "aeclass",
        help=
        "A string which matches the name of the model class available in latplan.model module.\n"+
        "It must be one of:\n"+
        "\n".join([ " "*4+name for name, cls in vars(latplan.model).items()
                    if type(cls) is type and \
                    issubclass(cls, latplan.network.Network) and \
                    cls is not latplan.network.Network
                ])
    )
    if objs:
        subparser.add_argument("location_representation",
                               nargs='?',
                               choices=["bbox","coord","binary","sinusoidal","anchor"],
                               default="coord",
                               help="A string which specifies how to convert/encode the location in the dataset. See documentations for normalize_transitions_objects")
        subparser.add_argument("randomize_location",
                               nargs='?',
                               type=bool,
                               default=False,
                               help="A boolean which specifies whether we randomly translate the environment globally. See documentations for normalize_transitions_objects")
    subparser.add_argument("comment",
                           nargs='?',
                           default="",
                           help="A string which is appended to the directory name to label each experiment.")
    
    subparser.add_argument("--hash",
                           nargs='?',
                           default="",
                           help="A string which replaces (forces) the last part of the directory name")
    


    subparser.add_argument("--label",
                           nargs='?',
                           default="",
                           help="A string which denote the label of the extracted_mutex file")


    subparser.add_argument("--loadweights",
                           nargs='?',
                           default="False",
                           help="A string which denote if we train with loading previous weights or not")


    subparser.add_argument("--nbepochs",
                           nargs='?',
                           default="1000",
                           help="A string which denote the number of epochs")


    subparser.add_argument("--invindex",
                           nargs='?',
                           default="0",
                           help="A string which denote the index of the invariant to test")


    subparser.add_argument("--nb_of_rounds",
                           nargs='?',
                           default="0",
                           help="A string which denote the index of the invariant to test")



    return



def main(parameters={}):
    import latplan.util.tuning
    latplan.util.tuning.parameters.update(parameters)

    import sys
    global args, sae_path
    args = parser.parse_args()

    
    task = args.task
    delattr(args,"task")
    print(vars(args))
    latplan.util.tuning.parameters.update(vars(args))


    if(sys.argv[2]=="puzzle"):
        sae_path = "_".join(sys.argv[2:9])
    if(sys.argv[2]=="blocks"):
        sae_path = "_".join(sys.argv[2:7])
    if(sys.argv[2]=="lightsout"):
        sae_path = "_".join(sys.argv[2:8])
    if(sys.argv[2]=="sokoban"):
        sae_path = "_".join(sys.argv[2:7])



    #sae_path = "_".join(sys.argv[2:])
    try:
        task(args)
    except:
        latplan.util.stacktrace.format()


################################################################
# procedures for each mode

def plot_autoencoding_image(ae,transitions,label):
    if 'plot' not in args.mode:
        return

    if hasattr(ae, "plot_transitions"):
        transitions = transitions[:6]
        ae.plot_transitions(transitions, ae.local(f"transitions_{label}"),verbose=True)
    else:
        transitions = transitions[:3]
        states = transitions.reshape((-1,*transitions.shape[2:]))
        ae.plot(states, ae.local(f"states_{label}"),verbose=True)

    return


def dump_all_actions(ae,configs,trans_fn,name = "all_actions.csv",repeat=1):
    if 'dump' not in args.mode:
        return
    l     = len(configs)
    batch = 5000
    loop  = (l // batch) + 1
    print(ae.local(name))
    with open(ae.local(name), 'wb') as f:
        for i in range(repeat):
            for begin in range(0,loop*batch,batch):
                end = begin + batch
                print((begin,end,len(configs)))
                transitions = trans_fn(configs[begin:end])
                pre, suc    = transitions[0], transitions[1]
                pre_b       = ae.encode(pre,batch_size=1000).round().astype(int)
                suc_b       = ae.encode(suc,batch_size=1000).round().astype(int)
                actions     = np.concatenate((pre_b,suc_b), axis=1)
                np.savetxt(f,actions,"%d")


def dump_actions(ae,transitions,name = "actions.csv", repeat=1):
    # if 'dump' not in args.mode:
    #     return
    # print(ae.local(name))
    ae.dump_actions(transitions, batch_size = 1000)


def dump_all_states(ae,configs,states_fn,name = "all_states.csv",repeat=1):
    if 'dump' not in args.mode:
        return
    l     = len(configs)
    batch = 5000
    loop  = (l // batch) + 1
    print(ae.local(name))
    with open(ae.local(name), 'wb') as f:
        for i in range(repeat):
            for begin in range(0,loop*batch,batch):
                end = begin + batch
                print((begin,end,len(configs)))
                states   = states_fn(configs[begin:end])
                states_b = ae.encode(states,batch_size=1000).round().astype(int)
                np.savetxt(f,states_b,"%d")


def dump_states(ae,states,name = "states.csv",repeat=1):
    if 'dump' not in args.mode:
        return
    print(ae.local(name))
    with open(ae.local(name), 'wb') as f:
        for i in range(repeat):
            np.savetxt(f,ae.encode(states,batch_size = 1000).round().astype(int),"%d")


def dump_code_unused():
    # This code is not used. Left here for copy-pasting in the future.
    if False:
        dump_states      (ae,all_states,"all_states.csv")
        dump_all_actions (ae,all_transitions_idx,
                          lambda idx: all_states[idx.flatten()].reshape((len(idx),2,num_objs,-1)).transpose((1,0,2,3)))


def train_val_test_split(x):
    train = x[:int(len(x)*0.9)]
    val   = x[int(len(x)*0.9):int(len(x)*0.95)]
    test  = x[int(len(x)*0.95):]
    return train, val, test


def run(path,transitions,extra=None):
    train, val, test = train_val_test_split(transitions)

    def postprocess(ae):
        show_summary(ae, train, test)
        plot_autoencoding_image(ae, train, "train")
        plot_autoencoding_image(ae, test, "test")
        dump_actions(ae, transitions)
        return ae


    def report(net, eval):
        try:
            postprocess(net)
            if extra:
                extra(net)
        except:
            latplan.util.stacktrace.format()
        return


    if(args.hash != ""):
        path_to_json = os.path.join(path+"/logs/"+args.hash)


    import json
    with open(os.path.join(path_to_json,"aux.json"),"r") as f:
        parameters = json.load(f)["parameters"]

    if(args.loadweights != ""):
        parameters["noweights"] = False if (args.loadweights == "True")  else True

    if(args.label != ""):
        parameters["label"] = args.label

    if(args.nbepochs != ""):
        parameters["epoch"] = int(args.nbepochs)


    parameters["invindex"]=0
    if args.invindex != "":
        parameters["invindex"]=int(args.invindex)


    if 'report' in args.mode:

        net = latplan.model.load(path)

        net.report(train, test_data = test, train_data_to=train, test_data_to=test)
    
        dump_actions(net, transitions)




    if 'dump' in args.mode:


        # prob ici c'est que ça load 
        net = latplan.model.load(path_to_json, allow_failure=True)
     
        dump_actions(net, transitions, name = "actions.csv", repeat=1)







    if 'learn' in args.mode:


        nb_of_rounds=1
        if args.nb_of_rounds != "":
            nb_of_rounds=int(args.nb_of_rounds)



        tab_invs = []

        #print(path_to_json)

        if(os.path.exists(path_to_json+"/found_variables_"+args.label+".txt")):

            with open(path_to_json+"/found_variables_"+args.label+".txt") as f:
                content = f.read()
                arr_content = content.split("#")

                for substr in arr_content:

                    sub_tab_invs = []

                    for c in substr.split("\n"):
                        
                        if(c != ""):
                            print(c)
                            sub_tab_invs.append(c)

                    tab_invs.append(sub_tab_invs)

            f.close()

        tab_invs = []

        # print("tab_invs")
        # print(tab_invs)
        

        # tab_invs
        parameters["invariants"] = tab_invs

        parameters["time_start"] = args.hash

        parameters["batch_size"] = 400

        # test_data = test



        f = open(path+"/val_metrics.txt", "w")
        f.write("")
        f.close()

        print("U1 ")

        nb_of_rounds=1


        
        for i in range(nb_of_rounds):


            print("U2 ")

            seed(2+i)

            task = curry(nn_task, latplan.model.get(parameters["aeclass"]), path, train, train, val, val, parameters, False) 
            task()

            f = open(path+"/val_metrics.txt", "a")
            f.write("\n")
            f.write("newTraining")
            f.write("\n")
            f.close()



    if 'resume' in args.mode:
        simple_genetic_search(
            lambda parameters: nn_task(latplan.model.get(parameters["aeclass"]), path, train, train, val, val, parameters, resume=True),
            parameters,
            path,
            limit              = 100,
            initial_population = 100,
            population         = 100,
            report             = report,
        )

    elif 'debug' in args.mode:
        print("debug run. removing past logs...")
        for _path in glob.glob(os.path.join(path,"*")):
            if os.path.isfile(_path):
                os.remove(_path)
        parameters["epoch"]=1
        parameters["batch_size"]=100
        train, val = train[:200], val[:200]
        simple_genetic_search(
            curry(nn_task, latplan.model.get(parameters["aeclass"]),
                  path,
                  train, train, val, val), # noise data is used for tuning metric
            parameters,
            path,
            limit              = 1,
            initial_population = 1,
            population         = 1,
            report             = report,
        )

    elif 'reproduce' in args.mode:   # reproduce the best result from the grid search log
        reproduce(
            curry(nn_task, latplan.model.get(parameters["aeclass"]),
                  path,
                  train, train, val, val), # noise data is used for tuning metric
            path,
            report      = report,
        )

    if 'iterate' in args.mode:
        wild = os.path.join(path,"logs","*")
        print(f"iterating mode {args.mode} for all weights stored under {wild}")
        for path in glob.glob(wild):
            postprocess(latplan.model.load(path))



def show_summary(ae, train, test):
    if 'summary' in args.mode:
        ae.summary()
        ae.report(train, test_data = test, train_data_to=train, test_data_to=test)


