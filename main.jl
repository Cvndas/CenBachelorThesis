module Cen
include("CenAstar.jl")
using .CenAstar
using MPI

#= run with
include("main.jl"); Cen.main_MPI_ParallelHierarchicSearch();
 =#
function main_MPI_ParallelHierarchicSearch()
    # TODO: Enter MPI immediately. 
    code = quote

        const MasterRank = 0
        include("CenAstar.jl")
        using .CenAstar

        using MPI
        MPI.Init()
        comm = MPI.COMM_WORLD
        nranks = MPI.Comm_size(comm)
        rank = MPI.Comm_rank(comm)
        host = MPI.Get_processor_name()
        println("Hello from $host, I am process $rank of $nranks processes!")

        if rank == MasterRank
            CenAstar.Initialize()
            println("Entered main_MPI_ParallelHierarchicSearch()")
            computedMaze::ComputedMaze = ComputeMaze()
            # allPathsDict = Dict{Tuple{Int,Int},MapTile}()
            # for mapTile in computedMaze.traversablePaths
            #     allPathsDict[(mapTile.x, mapTile.y)] = mapTile
            # end

            shortestPathTiles = CenAstar.MPI_ParallelHierarchicSearch(computedMaze.startTile, computedMaze.endTile, computedMaze.allTiles)
            attemptedPathTiles = MapTile[]

            println("Path is done. Going to render the maze now.")
            mazeImage = CenAstar.ShowMaze(computedMaze.wallMapTiles, computedMaze.pathMapTiles, computedMaze.mapBorders, shortestPathTiles, attemptedPathTiles)

            ComputePathCost = path -> sum(tile.costToReach for tile::MapTile in path)
            mpiPhsCost = ComputePathCost(shortestPathTiles)

            println("\n--- THE RESULTS ---\n")
            println("MPI PHS found a path with cost $mpiPhsCost")

            # TODO: Wait for the master rank to produce the maze. Like a barrier. Or maybe all should produce the maze, then
            # wait for the barrier.
        end

        MPI.Barrier(comm)
        println("I'm rank $rank and I'm done with the barrier!")


        if rank == MasterRank
            println("Press enter to exit")
            readline()
            # fig = Figure()
            println("Done with main().")
        end

        MPI.Finalize()
    end
    run(`$(mpiexec()) -np 4 julia --project=. -e $code`)


end


#= run with
include("main.jl"); Cen.main_SingleThreadedAStar();
 =#
function main_SingleThreadedAStar()
    CenAstar.Initialize()

    println("Entered main_SingleThreadedAStar()")
    # if COMPUTE_MAZE
    computedMaze::ComputedMaze = CenAstar.ComputeMaze()
    allPathsDict = Dict{Tuple{Int,Int},MapTile}()
    for mapTile in computedMaze.traversablePaths
        allPathsDict[(mapTile.x, mapTile.y)] = mapTile
    end

    println("Going to solve the maze with Single Threaded A*")
    @time shortestPathTiles = CenAstar.st_AStar(computedMaze.startTile, computedMaze.endTile, computedMaze.allTiles)

    # @assert computedMaze.wallMapTiles[1].color == :black "Wallmaptiles had wrong color"
    attemptedPathTiles = MapTile[]

    println("Path is done. Going to render the maze now.")
    mazeImage = CenAstar.ShowMaze(computedMaze.wallMapTiles, computedMaze.pathMapTiles, computedMaze.mapBorders, shortestPathTiles, attemptedPathTiles)
    # save("mazeImage.png", mazeImage)
    # TODO: Make ShowMaze return a figure, so I can put them side by side, give them a title, etc.
    ComputePathCost = path -> sum(tile.costToReach for tile::MapTile in path)
    AStar_Cost = ComputePathCost(shortestPathTiles)

    println("\n--- THE RESULTS ---\n")
    println("AStar found a path with cost $AStar_Cost")

    # fig = Figure()
    println("Done with main().")
end
end