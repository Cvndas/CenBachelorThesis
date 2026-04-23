module Cen
include("CenAstar.jl")
using .CenAstar
using MPI

#= run with
Cen.Clear()
 =#
function Clear()
    print("\33[2J\33[H")
end

#= run with
include("main.jl"); Cen.main_MPI_ParallelHierarchicSearch();
 =#
function main_MPI_ParallelHierarchicSearch()
    Clear()
    println("Started main()")
    code = quote
        using MPI
        include("CenAstar.jl")
        using .CenAstar

        MPI.Init()
        comm = MPI.Comm_dup(MPI.COMM_WORLD)
        nranks = MPI.Comm_size(comm)
        rank = MPI.Comm_rank(comm)
        host = MPI.Get_processor_name()
        println("Hello from $host, I am process $rank of $nranks processes!")
        # CenAstar.MPI_Naive_PhsEntry(comm, nranks, rank, host)
        CenAstar.MPI_Opt1_Entry(comm, nranks, rank, host)
        # CenAstar.SingleThreaded_PHS_ReferenceFunc_Entry(comm, nranks, rank, host)
        MPI.Finalize()
    end
    run(`$(mpiexec()) -np 8 julia --project=. -e $code`)
    # run(`$(mpiexec()) -np 4 julia --project=. -e $code`)
    # run(`$(mpiexec()) -np 3 julia --project=. -e $code`)
    # run(`$(mpiexec()) -np 2 julia --project=. -e $code`)


end




#= run with
include("main.jl"); Cen.main_SingleThreadedAStar();
 =#
function main_SingleThreadedAStar()
    Clear()
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

#Module Cen End
end