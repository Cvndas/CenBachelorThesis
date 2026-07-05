module Module_CenStar

export IsDas5

function IsDas5()
    hostname = get(ENV, "HOSTNAME", "")
    res = occursin("node", hostname) || occursin("das5", hostname) || occursin("fs0", hostname)
    # println("On Das5: $res")
    return res
end

#=
This is a module file. Its only purpose is to include the other files that make up Module_CenStar
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

include("CenStar_Benchmarking.jl")
if IsDas5() == false
    include("CenStar_Graphing_Core.jl")
end


include("MapTile_Functions.jl")
include("MapFunctions.jl")
include("MazeGenerator.jl")
if IsDas5() == false
    include("MakieRenderer.jl")
    include("MapBuilder.jl")
end
include("AStar_Shared.jl")
include("AStar_SingleThreaded.jl")
include("PHS_Shared.jl")
include("CenStar.jl")

export LoadMap
export CenStar_ProduceBenchmarkGraphs
# export MultiThreadedTestingGround
export RandomMazeSpecification
export HandcraftedMazeSpecification
export CenStar_RunConfig
export CenStar_GenerateReportString
export CenStar_PrintReports
end
