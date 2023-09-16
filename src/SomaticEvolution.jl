module SomaticEvolution

using Distributions
using Statistics
using Random
using StatsBase
using DataFrames
using GLM
using Printf
using CSV
using JSON
using DelimitedFiles
using AbstractTrees

export 
Cell,
TreeCell,
SimpleTreeCell,
BinaryNode,
MultiSimulation,
CellModule,
TreeModule,
SimulationInput,
BranchingMoranInput,
BranchingInput,
MoranInput,
MultilevelBranchingInput,
MultilevelBranchingMoranInput,
Simulation,
SampledData,
VAFResult,
VAFMultiResult,
WellMixed,
Linear,
TreeCellVector,
SimpleTreeCellVector,
AbstractTreeCellVector,
CellVector,

#functions for running multilevel or single-level simulations
runsimulation,
runsimulation_condfixtime,
runsimulation_condfixtime_to_nfixed,
runsimulation_timeseries,
runsimulation_timeseries_returnfinalpop,
run1simulation, 
multilevel_simulation,
multilevel_simulation_timeseries,
run_multilevel_from_file,
initialize,
allcells,

#functions for looking at VAF distributions (only implemented for Cell based simulations)
getallelefreq,
sampledallelefreq,
fitinverse,
gethist,
plotvaf,
plotvaf!,
plotinversevaf,
plotinversevaf!,
getVAFresult,
getVAFresultmulti,


#other statistics currently implemented only for Cell based simulations
shared_fixed_mutations,
subclonefreq,

#other statistics (work for Cell and (Simple)TreeCell simulations)
pairwisedistance,
pairwise_fixed_differences,
pairwise_fixed_differences_matrix,
pairwise_fixed_differences_statistics,
pairwise_fixed_differences_clonal,
newmoduletimes,
numbermodules,
average_mutations,
average_mutations_per_module,
mutations_per_cell,
clonal_mutations,
age,

#functions for TreeModule
endtime,
celllifetime,
celllifetimes,
getalivecells,
leftchild!,
rightchild!,
time_to_MRCA,
coalescence_times,
getsingleroot,
popsize,
findMRCA,
moduleid,

#util
newinput,
saveinput,
get_simulation,
saveinput,
loadinput

include("input.jl")
include("cells_modules.jl")
include("results.jl")
include("initialisation.jl")
include("simulations.jl")
include("multilevel.jl")
include("multilevel_condfixtime.jl")
include("run.jl")
include("process.jl")
include("samplingVAF.jl")
include("analyseVAF.jl")
include("multirun.jl")
include("util.jl")
include("statistics.jl")
include("io.jl")
include("simulation_trees.jl")




end