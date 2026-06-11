module CenAstar

#=
This is a module file. Its only purpose is to include the other files that make up CenAstar
=#

using GLMakie
using Colors
using Makie.Colors
using Random
using Dates

export MapTile
export HelloWorld
export ComputedMaze
export ComputeMaze
export RunMapBuilder


include("VariousStructs.jl")


using Serialization
include("Utilities.jl")
include("OPT1_Benchmarking.jl")
include("OPT1_Graphing.jl")


include("MapTile_Functions.jl")
include("MapFunctions.jl")
include("MazeGenerator.jl")
include("MakiePlayground.jl")
include("MakieRenderer.jl")
include("AStar_Shared.jl")
include("AStar_SingleThreaded.jl")
include("PHS_Shared.jl")
include("MPI_Naive_ParallelHierarchicSearch.jl")
include("Opt1_ParallelHierarchicSearch.jl")
include("ST_ParallelHierarchicSearch.jl")
include("MapBuilder/MapBuilder.jl")
include("MultithreadingPlayground.jl")

export LoadMap
export OPT1_ProduceBenchmarkGraphs
# export MultiThreadedTestingGround
export PseudoWorkerCore
export RandomMazeSpecification
export HandcraftedMazeSpecification
export OPT1_RunConfig

end
