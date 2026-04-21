module CenAstar

using GLMakie
using Colors
using Makie.Colors
using Random
using Dates
# using Serialization
include("Utilities.jl")
include("MapTile.jl")
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
end

function ComputeMaze()::ComputedMaze
    xMin = 0
    xMax = 500
    yMin = 0
    yMax = 500

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
    @assert startTile !== nothing "Start tile wasn't found"
    endTile = FindExistingMapTile(xMax, yMax, pathMapTiles)
    println("Found the end tile")
    @assert endTile !== nothing "End tile wasn't found"

    traversablePaths = [wallMapTiles; pathMapTiles]

    @time LoadNeighbors!(traversablePaths)
    computedMaze::ComputedMaze = ComputedMaze(startTile, endTile, traversablePaths, mapBorders, wallMapTiles, pathMapTiles)
    @assert wallMapTiles[1].color == :black "Wall map tiles color was not black: $(wallMapTiles[1].color)"
    return computedMaze
end





function main()
    # COMPUTE_MAZE = false
    # COMPUTE_MAZE = false

    println("Entered main()")
    seed = 5
    if seed < 0
        seed = Int(round(time()))
        println("Generated a seed based on time")
    end
    Random.seed!(seed)

    # if COMPUTE_MAZE
    println("Timing ComputeMaze()")
    @time computedMaze::ComputedMaze = ComputeMaze()
    allPathsDict = Dict{Tuple{Int,Int},MapTile}()
    for mapTile in computedMaze.traversablePaths
        allPathsDict[(mapTile.x, mapTile.y)] = mapTile
    end

    println("Going to solve the maze with Single Threaded A*")
    @time shortestPathTiles_AStar = st_AStar(computedMaze.startTile, computedMaze.endTile)

    @time shortestPathTiles_MPI_PHS = MPI_ParallelHierarchicSearch(computedMaze.startTile, computedMaze.endTile, allPathsDict)
    # @assert computedMaze.wallMapTiles[1].color == :black "Wallmaptiles had wrong color"
    attemptedPathTiles = MapTile[]

    println("Path is done. Going to render the maze now.")
    # mazeImage = ShowMaze(computedMaze.wallMapTiles, computedMaze.pathMapTiles, computedMaze.mapBorders, shortestPathTiles, attemptedPathTiles)
    # save("mazeImage.png", mazeImage)

    ComputePathCost = path -> sum(tile.costToReach for tile::MapTile in path)
    AStar_Cost = ComputePathCost(shortestPathTiles_AStar)
    MPI_PH_Cost = ComputePathCost(shortestPathTiles_MPI_PHS)

    println("\n--- THE RESULTS ---\n")
    println("AStar found a path with cost $AStar_Cost")
    println("MPI Parallel Hierarchic Search found a path with cost $MPI_PH_Cost")

    # fig = Figure()
    println("Done with main().")
end





main()


end