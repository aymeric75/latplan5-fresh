#!/usr/bin/env python3


options = {
    "lmcut" : "--search astar(lmcut())",
    "blind" : "--search astar(blind())",
    "hmax"  : "--search astar(hmax())",
    "ff"    : "--search eager(single(ff()))",
    "lff"   : "--search lazy_greedy(ff())",
    "lffpo" : "--evaluator h=ff() --search lazy_greedy(h, preferred=h)",
    "gc"    : "--search eager(single(goalcount()))",
    "lgc"   : "--search lazy_greedy(goalcount())",
    "lgcpo" : "--evaluator h=goalcount() --search lazy_greedy(h, preferred=h)",
    "cg"    : "--search eager(single(cg()))",
    "lcg"   : "--search lazy_greedy(cg())",
    "lcgpo" : "--evaluator h=cg() --search lazy_greedy(h, preferred=h)",
    "lama"  : "--alias lama-first",
    "oldmands" : "--search astar(merge_and_shrink(shrink_strategy=shrink_bisimulation(max_states=50000,greedy=false),merge_strategy=merge_dfp(),label_reduction=exact(before_shrinking=true,before_merging=false)))",
    "mands"    : "--search astar(merge_and_shrink(shrink_strategy=shrink_bisimulation(greedy=false),merge_strategy=merge_sccs(order_of_sccs=topological,merge_selector=score_based_filtering(scoring_functions=[goal_relevance,dfp,total_order])),label_reduction=exact(before_shrinking=true,before_merging=false),max_states=50k,threshold_before_merge=1))",
    "pdb"   : "--search astar(pdb())",
    "cpdb"  : "--search astar(cpdbs())",
    "ipdb"  : "--search astar(ipdb())",
    "zopdb"  : "--search astar(zopdbs())",
}


# import argparse
# parser = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter)
# parser.add_argument("domainfile", help="pathname to a PDDL domain file")
# parser.add_argument("problem_dir", help="pathname to a directory containing init.png and goal.png")
# parser.add_argument("heuristics", choices=options.keys(),
#                     help="heuristics configuration passed to fast downward. The details are:\n"+
#                     "\n".join([ " "*4+key+"\n"+" "*8+value for key,value in options.items()]))
# parser.add_argument("cycle", type=int, default=1, nargs="?",
#                     help="number of autoencoding cycles to perform on the initial/goal images")
# parser.add_argument("sigma", type=str, default=None, nargs="?",
#                     help="sigma of the Gaussian noise added to the normalized initial/goal images.")

# parser.add_argument("extension", type=str, default=None, nargs="?",
#                     help="extension for name of image files.")
# args = parser.parse_args()


import subprocess
import os
import sys
import latplan
import latplan.model
from latplan.util import *
from latplan.util.planner import *
from latplan.util.plot import *
import latplan.util.stacktrace


import os.path
import keras.backend as K
import tensorflow as tf
import math
import time
import json

import numpy as np
float_formatter = lambda x: "%.3f" % x
np.set_printoptions(threshold=sys.maxsize,formatter={'float_kind':float_formatter})




def main():
    print("hello")

if __name__ == '__main__':
   
    main()
  