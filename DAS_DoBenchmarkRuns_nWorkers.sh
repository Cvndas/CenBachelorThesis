#!/bin/bash

module load julia
# module load openmpi/gcc
module load openmpi4/4.1.6
module load prun

PROCS_PER_NODE=1
NODES=$(($1 + 1))
TOTAL_PROCS=$((NODES * PROCS_PER_NODE))
prun -v -${PROCS_PER_NODE} -np ${TOTAL_PROCS} -t 1800 -script $PRUN_ETC/prun-openmpi-mpiexecjl julia DAS_BenchmarkRun.jl
