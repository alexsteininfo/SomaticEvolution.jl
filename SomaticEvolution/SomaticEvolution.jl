module SomaticEvolution

using Distributions
using Statistics
using Random
using StatsBase
using DataFrames
using RecipesBase
using GLM
using LaTeXStrings
using Printf
using CSV


export Cell,
MultiSimulation,
SimulationTracker,
SimulationInput,
BranchingInput,
MoranInput,
InputParameters,
Simulation,
SampledData,
PlotVAF,
PlotInverseVAF,

multiplesimulations,
run1simulation, 
sampledhist,
fitinverse,
gethist,
plotvaf,
plotvaf!,
plotinversevaf,
plotinversevaf!,
getstats,
saveinput,
branchingprocess,
moranprocess

include("definetypes.jl")
include("runsimulations.jl")
include("process.jl")
include("sampling.jl")
include("analyse.jl")
include("multirun.jl")
include("plot.jl")
include("util.jl")



end