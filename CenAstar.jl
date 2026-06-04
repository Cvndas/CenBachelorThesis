
module CenAstar

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
include("Benchmarking.jl")


include("MazeGenerator.jl")
include("MakiePlayground.jl")
include("MakieRenderer.jl")
include("AStar_Shared.jl")
include("AStar_SingleThreaded.jl")
include("MapTile_Functions.jl")
include("MPI_Naive_ParallelHierarchicSearch.jl")
include("Opt1_ParallelHierarchicSearch.jl")
include("PHS_Shared.jl")
include("ST_ParallelHierarchicSearch.jl")
include("MapBuilder/MapBuilder.jl")
include("MultithreadingPlayground.jl")

export LoadMap
export OPT1_ProduceBenchmarkGraphs
# export MultiThreadedTestingGround
export PseudoWorkerCore

#=
This is a module file. Its purpose is to include the other files that make up CenAstar
=#


# TODO: organize the remaining functions in here into correct files.

function GenerateMapBorders(xMin::Int32, xMax::Int32, yMin::Int32, yMax::Int32)
    mapBorders = MutableMapTile[]
    for x::Int32 in xMin-1:xMax+1
        push!(mapBorders, CreateMapBorder(x, Int32(yMin - 1)))
        push!(mapBorders, CreateMapBorder(x, Int32(yMax + 1)))
    end
    for y::Int32 in yMin:yMax
        push!(mapBorders, CreateMapBorder(Int32(xMin - 1), y))
        push!(mapBorders, CreateMapBorder(Int32(xMax + 1), y))
    end
    return mapBorders
end


function FindExistingMapTile(x, y, existingTiles::Array{MutableMapTile})
    for existingTile in existingTiles
        if existingTile.x == x && existingTile.y == y
            return existingTile
        end
    end
    return nothing
end


function LoadMap(mapName::String)

    dir = "Custom Maps"
    path = joinpath(dir, mapName * ".map")

    loaded::SavedMaze = open(path, "r") do file
        deserialize(file)
    end

    wayPoints::Array{MapTile,1} = []

    traversablePaths_Dict = Dict{Tuple{Int32,Int32},MapTile}()

    allMapTiles::Array{MapTile,2} = Array{MapTile,2}(undef, loaded.xMax, loaded.yMax)

    for mutableMapTile in loaded.mapTiles
        asImmutable::MapTile = MakeImmutable(mutableMapTile)
        # push!(traversablePaths, asImmutable)
        traversablePaths_Dict[(mutableMapTile.x, mutableMapTile.y)] = asImmutable

        allMapTiles[mutableMapTile.x, mutableMapTile.y] = asImmutable
    end

    WayPointExists = (wayPoint::Tuple{Int32,Int32}) -> wayPoint[1] >= 1 && wayPoint[2] >= 1
    for wayPoint::Tuple{Int32,Int32} in loaded.wayPoints
        if WayPointExists(wayPoint)
            push!(wayPoints, traversablePaths_Dict[wayPoint])
        end
    end

    startTile::MapTile = wayPoints[1]
    endTile::MapTile = wayPoints[end]

    mapBordersMutable::Array{MutableMapTile} = GenerateMapBorders(Int32(1), loaded.xMax, Int32(1), loaded.yMax)
    mapBorders::Array{MapTile} = []
    for mut in mapBordersMutable
        push!(mapBorders, MakeImmutable(mut))
    end
    return ComputedMaze(
        startTile,
        endTile,
        mapBorders,
        allMapTiles,
        wayPoints)
end


function ComputeMaze(mazeSize_X::Int32, mazeSize_Y::Int32)::ComputedMaze
    xMin::Int32 = 1
    xMax::Int32 = mazeSize_X
    yMin::Int32 = 1
    yMax::Int32 = mazeSize_Y

    @assert xMin == 1 # Never Change
    @assert yMin == 1 # Never Change

    walls = PrimsMazeGenerator(xMin, xMax, yMin, yMax)
    PunctureHoles!(walls)

    mutable_wallMapTiles = [CreateWall(Int32(x), Int32(y)) for (x, y) in walls]
    mutable_pathMapTiles = GeneratePathTiles(walls, xMin, xMax, yMin, yMax)
    mutable_mapBorders = GenerateMapBorders(xMin, xMax, yMin, yMax)

    mutable_startTile = FindExistingMapTile(xMin, yMin, mutable_pathMapTiles)
    mutable_endTile = FindExistingMapTile(xMax, yMax, mutable_pathMapTiles)

    mutable_traversablePaths = [mutable_wallMapTiles; mutable_pathMapTiles]

    width = xMax
    height = yMax




    # // ::: -------------------------:: Making it all immutable ::------------------------- ::: //
    CreateImmutableMapTileArray = (mutableArray::Array{MutableMapTile}) -> [MapTile(mut.x, mut.y, costToReach=mut.costToReach) for mut::MutableMapTile in mutableArray]

    startTile = MakeImmutable(mutable_startTile)
    endTile = MakeImmutable(mutable_endTile)
    traversablePaths = CreateImmutableMapTileArray(mutable_traversablePaths)
    mapBorders = CreateImmutableMapTileArray(mutable_mapBorders)
    # wallMapTiles = CreateImmutableMapTileArray(mutable_wallMapTiles)
    # pathMapTiles = CreateImmutableMapTileArray(mutable_pathMapTiles)

    allTiles2DArray = Array{MapTile,2}(undef, width, height)
    for path::MapTile in traversablePaths
        allTiles2DArray[path.x, path.y] = path
    end

    computedMaze::ComputedMaze = ComputedMaze(startTile, endTile, mapBorders, allTiles2DArray, [])
    return computedMaze
end





function InitializeSeed()::Int
    config = include("Config.jl")
    seed = config.seed
    # seed = 5
    if seed < 0
        seed = Int(round(time()))
    end
    # println("Initialized with seed $seed")
    Random.seed!(seed)
    return seed
end










# if abspath(PROGRAM_FILE) == @__FILE__
#     main()
# end


end
