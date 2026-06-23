module CenAstar

export IsDas5

function IsDas5()
    hostname = get(ENV, "HOSTNAME", "")
    res = occursin("node", hostname) || occursin("das5", hostname) || occursin("fs0", hostname)
    # println("On Das5: $res")
    return res
end

#=
This is a module file. Its only purpose is to include the other files that make up CenAstar
=#

if IsDas5() == false
    using GLMakie
    using Colors
    using Makie.Colors
end
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
if IsDas5() == false
    include("OPT1_Graphing_Core.jl")
end


include("MapTile_Functions.jl")
include("MapFunctions.jl")
include("MazeGenerator.jl")
if IsDas5() == false
    include("MakiePlayground.jl")
    include("MakieRenderer.jl")
    include("MapBuilder/MapBuilder.jl")
end
include("AStar_Shared.jl")
include("AStar_SingleThreaded.jl")
include("PHS_Shared.jl")
include("MPI_Naive_ParallelHierarchicSearch.jl")
include("Opt1_ParallelHierarchicSearch.jl")
include("ST_ParallelHierarchicSearch.jl")
include("MultithreadingPlayground.jl")

export LoadMap
export OPT1_ProduceBenchmarkGraphs
# export MultiThreadedTestingGround
export PseudoWorkerCore
export RandomMazeSpecification
export HandcraftedMazeSpecification
export OPT1_RunConfig
export OPT1_GenerateReportString
export OPT1_PrintReports
end
