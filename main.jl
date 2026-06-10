include("CenAstar.jl")
using .CenAstar
using MPI

#= run with
Cen.Clear()
 =#
function Clear()
    print("\33[2J\33[H")
end

#=
TODO very crucial:
For randomly generated maps, when placing waypoints, make sure they are not placed on walls ,as
in its current state maybe it is going to search for all the nodes that are cheaper than that
    waypoint sitting on a wall.
    Shouldn't be too difficult to fix. Just try all the neighbors to put the waypoint on it. If
    no, add those neighbors to a frontier, try the same thing on that frontier, until one waypoint is
    found that is not on a wall.
#=
=#
=#

#=
TODO: 
For the benchmarking in the OPT1 file, when a worker has sent its beautification path, 
it needs to wait for a signal from the master to send a benchmarking data package.

Important that these benchmarking packages are only being sent over to the master when 
the actual work is fully complete, so there's no network congestion or other overhead
from non-work packages being sent over MPI.


=#

# TODO: Functionality to run the entire benchmark for each map and core config
# x times in a row, and discarding the result of the first run, then storing
# the average, the lowest, the fastest, etc, and using the averages to compare
# to the single threaded and other configurations of MPI

# TODO: Only when this warmup stuff is implemented, check the benchmarks 
# for suspicious values, to sniff out any potential benchmarking bugs

function RunThreadcountAsserts()
    threadCount = Threads.nthreads()
    if threadCount != 1
        error("Threadcount is not 1. Start julia with 1 thread when running this function")
    end
end

#= Run with
include("main.jl"); main_OPT1_SingleRun(_, _);
=#
function main_OPT1_SingleRun(workerCount, mazeXY)
    Clear()
    RunThreadcountAsserts()
    println("Starting the Run with config[workerCount: $workerCount, mazeXY: $mazeXY]")
    if (workerCount < 1)
        error("Need minimum 1 worker to run this")
    end
    config = include("config.jl")

    path = config.PATH_SingleRun
    mkpath(path)
    for file in readdir(path, join=true)
        if isfile(file)
            rm(file)
        end
    end
    println("Cleared the old benchmarking data in $path")



    code = quote
        using MPI
        include("CenAstar.jl")
        using .CenAstar

        randomMazeSpec = RandomMazeSpecification($(mazeXY), $(mazeXY))
        runConfig::OPT1_RunConfig = OPT1_RunConfig([randomMazeSpec], false, 1)

        MPI.Init()
        comm = MPI.Comm_dup(MPI.COMM_WORLD)
        nranks = MPI.Comm_size(comm)
        rank = MPI.Comm_rank(comm)
        masterCore = 0
        processorName = MPI.Get_processor_name()
        # println("Hello from $processorName, I am process $rank of $nranks processes!")

        CenAstar.OPT1_Entry_BenchmarkingRunA(comm, nranks, rank, masterCore, runConfig)

        MPI.Finalize()
    end

    # Here, specify what to run
    run(`$(mpiexec()) -np $(workerCount+1) julia --project=. --threads=2 -e $code`)

end


function main_MPI_ParallelHierarchicSearch_BenchmarkingRunA()
    Clear()
    RunThreadcountAsserts()
    println("Starting the Benchmarking Run A")

    config = include("config.jl")
    path = config.PATH_BenchmarkingRun_A
    mkpath(path)
    for file in readdir(path, join=true)
        if isfile(file)
            rm(file)
        end
    end

    code = quote
        using MPI
        include("CenAstar.jl")
        using .CenAstar

        mazeSizes = [100, 250, 500, 750, 1000, 2000, 5000]

        MPI.Init()
        comm = MPI.Comm_dup(MPI.COMM_WORLD)
        nranks = MPI.Comm_size(comm)
        rank = MPI.Comm_rank(comm)
        masterCore = 0
        processorName = MPI.Get_processor_name()
        # println("Hello from $processorName, I am process $rank of $nranks processes!")

        CenAstar.OPT1_Entry_BenchmarkingRunA(comm, nranks, rank, masterCore, mazeSizes, false)

        MPI.Finalize()
    end

    # Here, specify what to run
    run(`$(mpiexec()) -np 2 julia --project=. -e $code`)
    run(`$(mpiexec()) -np 3 julia --project=. -e $code`)
    run(`$(mpiexec()) -np 4 julia --project=. -e $code`)
    run(`$(mpiexec()) -np 5 julia --project=. -e $code`)
    run(`$(mpiexec()) -np 6 julia --project=. -e $code`)
    run(`$(mpiexec()) -np 7 julia --project=. -e $code`)
end

#= run in the julia repl with
include("main.jl"); main_MPI_ParallelHierarchicSearch_ProduceBenchmarkGraphs_RunA();
=#
function main_MPI_ParallelHierarchicSearch_ProduceBenchmarkGraphs_RunA()
    RunThreadcountAsserts()
    runAFolder = joinpath("Benchmarks", "RunA")
    CenAstar.OPT1_ProduceBenchmarkGraphs(runAFolder)
end

#= run in the julia repl with
include("main.jl"); main_MPI_ParallelHierarchicSearch_HandcraftedMaps();
=#
function main_MPI_ParallelHierarchicSearch_HandcraftedMaps()
    Clear()
    RunThreadcountAsserts()
    println("Started main()")
    code = quote
        using MPI
        include("CenAstar.jl")
        using .CenAstar

        MPI.Init()
        comm = MPI.Comm_dup(MPI.COMM_WORLD)
        nranks = MPI.Comm_size(comm)
        rank = MPI.Comm_rank(comm)
        processorName = MPI.Get_processor_name()
        masterCore = 0

        # TODO: Define a proper configuration object that I pass in, which includes maze size, 
        # multithreading, maze type, etc. And build it inside of Entry() so that the code will
        # actually have access to it. 
        multithread = false
        println("Hello from $processorName, I am process $rank of $nranks processes!")
        # CenAstar.MPI_Naive_PhsEntry(comm, nranks, rank, host)
        CenAstar.OPT1_Entry(comm, nranks, rank, masterCore, true)
        # CenAstar.SingleThreaded_PHS_ReferenceFunc_Entry(comm, nranks, rank, host)
        MPI.Finalize()
    end
    run(`$(mpiexec()) -np 8 julia --project=. -e $code`)
    # run(`$(mpiexec()) -np 4 julia --project=. -e $code`)
    # run(`$(mpiexec()) -np 3 julia --project=. -e $code`)
    # run(`$(mpiexec()) -np 2 julia --project=. -e $code`)
end

#= run in the julia repl with
include("main.jl"); main_MPI_ParallelHierarchicSearch();
=#
function main_MPI_ParallelHierarchicSearch()
    Clear()
    RunThreadcountAsserts()
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
        CenAstar.OPT1_Entry(comm, nranks, rank, host, false)
        # CenAstar.SingleThreaded_PHS_ReferenceFunc_Entry(comm, nranks, rank, host)
        MPI.Finalize()
    end
    # run(`$(mpiexec()) -np 8 julia --project=. -e $code`)
    run(`$(mpiexec()) -np 4 julia --project=. -e $code`)
    # run(`$(mpiexec()) -np 3 julia --project=. -e $code`)
    # run(`$(mpiexec()) -np 2 julia --project=. -e $code`)

end

#= run in the julia repl with
include("main.jl"); main_MapBuilder();
=#
function main_MapBuilder(; mapToEdit::String="")
    Clear()
    CenAstar.InitializeSeed()
    CenAstar.RunMapBuilder(mapToEdit)

    println("Exiting main()")
end

#= run with
include("main.jl"); main_SingleThreadedAStar();
 =#
function main_SingleThreadedAStar()
    Clear()
    error("This whole code path is incompatible with many recent code changes and also irrelevant, as single-threaded A* been integrated into OPT1.")
    CenAstar.InitializeSeed()

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
    # mazeImage = CenAstar.ShowMaze(computedMaze.wallMapTiles, computedMaze.pathMapTiles, computedMaze.mapBorders, shortestPathTiles, attemptedPathTiles)
    # save("mazeImage.png", mazeImage)
    # TODO: Make ShowMaze return a figure, so I can put them side by side, give them a title, etc.
    ComputePathCost = path -> sum(tile.costToReach for tile::MapTile in path)
    AStar_Cost = ComputePathCost(shortestPathTiles)

    println("\n--- THE RESULTS ---\n")
    println("AStar found a path with cost $AStar_Cost")

    # fig = Figure()
    println("Done with main().")
end

#= run with
include("main.jl"); main_PseudoWorkerCore();
 =#
function main_PseudoWorkerCore()
    CenAstar.PseudoWorkerCore()
end

#= run with
include("main.jl"); main_MultiThreadedTesting();
 =#
# function main_MultiThreadedTesting()
#     CenAstar.MultiThreadedTestingGround()
# end

