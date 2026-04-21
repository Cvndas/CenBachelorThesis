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


include("MapTile.jl")

# using Serialization
include("Utilities.jl")



include("MazeGenerator.jl")
include("MakiePlayground.jl")
include("MakieRenderer.jl")
include("AStar_Shared.jl")
include("AStar_SingleThreaded.jl")
include("MPI_ParallelHierarchicSearch.jl")
include("MapTile_Functions.jl")





function GenerateMapBorders(xMin, xMax, yMin, yMax)
    mapBorders = MapTile[]
    for x in xMin-1:xMax+1
        push!(mapBorders, CreateMapBorder(x, yMin - 1))
        push!(mapBorders, CreateMapBorder(x, yMax + 1))
    end
    for y in yMin:yMax
        push!(mapBorders, CreateMapBorder(xMin - 1, y))
        push!(mapBorders, CreateMapBorder(xMax + 1, y))
    end
    return mapBorders
end


function FindExistingMapTile(x, y, existingTiles::Array{MapTile})
    for existingTile in existingTiles
        if existingTile.x == x && existingTile.y == y
            return existingTile
        end
    end
    return nothing
end



struct ComputedMaze
    startTile::MapTile
    endTile::MapTile
    traversablePaths::Array{MapTile}
    mapBorders::Array{MapTile}
    wallMapTiles::Array{MapTile}
    pathMapTiles::Array{MapTile}
    allTiles::Array{MapTile,2}
end

function ComputeMaze()::ComputedMaze
    xMin = 1
    xMax = 500
    yMin = 1
    yMax = 500

    @assert xMin == 1 # Never Change
    @assert yMin == 1 # Never Change

    walls = PrimsMazeGenerator(xMin, xMax, yMin, yMax)
    PunctureHoles!(walls)

    wallMapTiles = [CreateWall(x, y) for (x, y) in walls]
    println("Generated the walls")
    pathMapTiles = GeneratePathTiles(walls, xMin, xMax, yMin, yMax)
    println("Generated the path tiles")
    mapBorders = GenerateMapBorders(xMin, xMax, yMin, yMax)
    println("Generated the map borders")

    startTile = FindExistingMapTile(xMin, yMin, pathMapTiles)
    println("Found the start tile")
    endTile = FindExistingMapTile(xMax, yMax, pathMapTiles)
    println("Found the end tile")

    traversablePaths = [wallMapTiles; pathMapTiles]

    width = xMax
    height = yMax

    allTiles2DArray = Array{MapTile,2}(undef, width, height)
    for path::MapTile in traversablePaths
        allTiles2DArray[path.x, path.y] = path
    end

    computedMaze::ComputedMaze = ComputedMaze(startTile, endTile, traversablePaths, mapBorders, wallMapTiles, pathMapTiles, allTiles2DArray)
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