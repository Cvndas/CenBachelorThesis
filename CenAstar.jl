
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


include("VariousStructs.jl")


# using Serialization
include("Utilities.jl")



include("MazeGenerator.jl")
include("MakiePlayground.jl")
include("MakieRenderer.jl")
include("AStar_Shared.jl")
include("AStar_SingleThreaded.jl")
include("MapTile_Functions.jl")
include("PHS/MPI_Naive_ParallelHierarchicSearch.jl")
include("PHS/MPI_Opt1_ParallelHierarchicSearch.jl")
include("PHS/PHS_Shared.jl")
include("PHS/ST_ParallelHierarchicSearch.jl")

const MAZE_SIZE_X = 200
const MAZE_SIZE_Y = 200

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




function ComputeMaze()::ComputedMaze
    println("\n\n--- GENERATING A MAZE --\n")
    xMin::Int32 = 1
    xMax::Int32 = MAZE_SIZE_X
    yMin::Int32 = 1
    yMax::Int32 = MAZE_SIZE_Y

    @assert xMin == 1 # Never Change
    @assert yMin == 1 # Never Change

    walls = PrimsMazeGenerator(xMin, xMax, yMin, yMax)
    PunctureHoles!(walls)

    mutable_wallMapTiles = [CreateWall(Int32(x), Int32(y)) for (x, y) in walls]
    println("Generated the walls")
    mutable_pathMapTiles = GeneratePathTiles(walls, xMin, xMax, yMin, yMax)
    println("Generated the path tiles")
    mutable_mapBorders = GenerateMapBorders(xMin, xMax, yMin, yMax)
    println("Generated the map borders")

    mutable_startTile = FindExistingMapTile(xMin, yMin, mutable_pathMapTiles)
    println("Found the start tile")
    mutable_endTile = FindExistingMapTile(xMax, yMax, mutable_pathMapTiles)
    println("Found the end tile")

    mutable_traversablePaths = [mutable_wallMapTiles; mutable_pathMapTiles]

    width = xMax
    height = yMax


    # // ::: -------------------------:: Making it all immutable ::------------------------- ::: // 
    CreateImmutableMapTileArray = (mutableArray::Array{MutableMapTile}) -> [MapTile(mut.x, mut.y, costToReach=mut.costToReach) for mut::MutableMapTile in mutableArray]

    startTile = MakeImmutable(mutable_startTile)
    endTile = MakeImmutable(mutable_endTile)
    traversablePaths = CreateImmutableMapTileArray(mutable_traversablePaths)
    mapBorders = CreateImmutableMapTileArray(mutable_mapBorders)
    wallMapTiles = CreateImmutableMapTileArray(mutable_wallMapTiles)
    pathMapTiles = CreateImmutableMapTileArray(mutable_pathMapTiles)

    allTiles2DArray = Array{MapTile,2}(undef, width, height)
    for path::MapTile in traversablePaths
        allTiles2DArray[path.x, path.y] = path
    end

    computedMaze::ComputedMaze = ComputedMaze(startTile, endTile, traversablePaths, mapBorders, wallMapTiles, pathMapTiles, allTiles2DArray)
    println("\n--- MAZE GENERATION DONE --\n\n")
    return computedMaze
end





function Initialize()
    seed = 5
    if seed < 0
        seed = Int(round(time()))
    end
    println("Initialized with seed $seed")
    Random.seed!(seed)
end










# if abspath(PROGRAM_FILE) == @__FILE__
#     main()
# end


end