include("CenAstar.jl")
using .CenAstar
using Serialization
using MPI

function IsDas5()
    hostname = get(ENV, "HOSTNAME", "")
    res = occursin("node", hostname) || occursin("das5", hostname) || occursin("fs0", hostname)
    # println("On Das5: $res")
    return res
end

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


# When running with more than 32 cores (which I need to do as I need 32 workers, i.e. also one more for the master)
# there's an aggressive timeout. This function is intended to be called one maze at at time.
function main_OPT1_DasBenchmark_HighCoreCount(mazeSize)
    Clear()
    if IsDas5() == false
        error("This function only runs on DAS")
    end

    MPI.Init()
    comm = MPI.Comm_dup(MPI.COMM_WORLD)
    nranks = MPI.Comm_size(comm)
    rank = MPI.Comm_rank(comm)
    processorName = MPI.Get_processor_name()

    config = include("Config.jl")
    path = "$(config.PATH_DasRun)_with_$(nranks)_ranks_withScaling_$(config.LEVEL_SCALING)"
    mkpath(path)
    # for file in readdir(path, join=true)
    #     if isfile(file)
    #         rm(file)
    #     end
    # end
    println("Cleared the old benchmarking data in $path")

    mazeXYs = [mazeSize]
    mazeSpecs = []
    for mazeXY in mazeXYs
        push!(mazeSpecs, RandomMazeSpecification(mazeXY, mazeXY))
    end

    runConfig::OPT1_RunConfig = OPT1_RunConfig(mazeSpecs, false, path)
    println("Hello from $processorName on DAS-5, I am process $rank of $nranks processes!")
    CenAstar.OPT1_Entry_BenchmarkingRunA(comm, nranks, rank, runConfig, bypassAveraging=true)
    MPI.Finalize()
end


function main_OPT1_DasBenchmarks()
    Clear()
    if IsDas5() == false
        error("This function only runs on DAS")
    end

    RunThreadcountAsserts()
    MPI.Init()
    comm = MPI.Comm_dup(MPI.COMM_WORLD)
    nranks = MPI.Comm_size(comm)
    rank = MPI.Comm_rank(comm)
    processorName = MPI.Get_processor_name()

    config = include("Config.jl")
    path = "$(config.PATH_DasRun)_with_$(nranks)_ranks_withScaling_$(config.LEVEL_SCALING)"
    mkpath(path)
    # for file in readdir(path, join=true)
    #     if isfile(file)
    #         rm(file)
    #     end
    # end
    println("Cleared the old benchmarking data in $path")

    mazeXYs = [100, 200, 500, 1000, 2000, 5000]
    mazeSpecs = []
    for mazeXY in mazeXYs
        push!(mazeSpecs, RandomMazeSpecification(mazeXY, mazeXY))
    end

    runConfig::OPT1_RunConfig = OPT1_RunConfig(mazeSpecs, false, path)
    println("Hello from $processorName on DAS-5, I am process $rank of $nranks processes!")
    CenAstar.OPT1_Entry_BenchmarkingRunA(comm, nranks, rank, runConfig)
    MPI.Finalize()
end



#= Run with
include("main.jl"); main_OPT1_SingleRun(_, _);
=#
function main_OPT1_SingleRun(workerCount, mazeXY, multiThread)
    Clear()
    RunThreadcountAsserts()
    println("Starting the Run with config[workerCount: $workerCount, mazeXY: $mazeXY]")
    if (workerCount < 1)
        error("Need minimum 1 worker to run this")
    end
    config = include("Config.jl")

    path = config.PATH_SingleRun
    mkpath(path)
    for file in readdir(path, join=true)
        if isfile(file)
            rm(file)
        end
    end
    println("Cleared the old benchmarking data in $path")

    if IsDas5()
        println("RUNNING ON DAS-5")

        MPI.Init()
        comm = MPI.Comm_dup(MPI.COMM_WORLD)
        nranks = MPI.Comm_size(comm)
        rank = MPI.Comm_rank(comm)
        masterCore = 0
        processorName = MPI.Get_processor_name()

        randomMazeSpec = RandomMazeSpecification(mazeXY, mazeXY)
        runConfig::OPT1_RunConfig = OPT1_RunConfig([randomMazeSpec], multiThread, path)
        println("Hello from $processorName on DAS-5, I am process $rank of $nranks processes!")

        CenAstar.OPT1_Entry_BenchmarkingRunA(comm, nranks, rank, runConfig)

        MPI.Finalize()
    else
        code = quote
            using MPI
            include("CenAstar.jl")
            using .CenAstar

            config = include("Config.jl")

            randomMazeSpec = RandomMazeSpecification($(mazeXY), $(mazeXY))
            runConfig::OPT1_RunConfig = OPT1_RunConfig([randomMazeSpec], $(multiThread), config.PATH_SingleRun)

            MPI.Init()
            comm = MPI.Comm_dup(MPI.COMM_WORLD)
            nranks = MPI.Comm_size(comm)
            rank = MPI.Comm_rank(comm)
            masterCore = 0
            processorName = MPI.Get_processor_name()
            # println("Hello from $processorName, I am process $rank of $nranks processes!")

            CenAstar.OPT1_Entry_BenchmarkingRunA(comm, nranks, rank, runConfig)

            MPI.Finalize()
        end

        run(`$(mpiexec()) -np $(workerCount+1) julia --project=. --threads=2 -e $code`)
    end


end


function main_OPT1_RunA_RunBenchmarks()
    Clear()
    RunThreadcountAsserts()
    println("Starting the Benchmarking Run A")

    config = include("Config.jl")
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

        mazeSpecs = [
            RandomMazeSpecification(100, 100),
            RandomMazeSpecification(250, 250),
            RandomMazeSpecification(500, 500),
            RandomMazeSpecification(750, 750),
            # RandomMazeSpecification(1000, 1000),
            # RandomMazeSpecification(2000, 2000),
            # RandomMazeSpecification(5000, 5000)
        ]

        MPI.Init()
        comm = MPI.Comm_dup(MPI.COMM_WORLD)
        nranks = MPI.Comm_size(comm)
        rank = MPI.Comm_rank(comm)
        masterCore = 0
        processorName = MPI.Get_processor_name()
        # println("Hello from $processorName, I am process $rank of $nranks processes!")

        runConfig::OPT1_RunConfig = OPT1_RunConfig(mazeSpecs, false, $(path))
        CenAstar.OPT1_Entry_BenchmarkingRunA(comm, nranks, rank, runConfig)

        MPI.Finalize()
    end


    # debugFlags = ""
    # releaseFlags = "--check-bounds=no -O3"

    # release = true
    # if release
    #     flags = releaseFlags
    # else
    #     flags = debugFlags
    # end


    # Here, specify what to run
    run(`$(mpiexec()) -np 3 julia  --project=. -e $code`)
    run(`$(mpiexec()) -np 5 julia  --project=. -e $code`)
    run(`$(mpiexec()) -np 9 julia  --project=. -e $code`)
    # run(`$(mpiexec()) -np 5 julia  --project=. -e $code`)
    # run(`$(mpiexec()) -np 6 julia  --project=. -e $code`)
    # run(`$(mpiexec()) -np 7 julia  --project=. -e $code`)
end

#= run in the julia repl with
include("main.jl"); main_MPI_ParallelHierarchicSearch_ProduceBenchmarkGraphs_RunA();
=#
function main_OPT1_RunA_ProduceGraphs()
    RunThreadcountAsserts()
    runAFolder = joinpath("Benchmarks", "RunA")
    CenAstar.OPT1_ProduceBenchmarkingGraphs_V2(runAFolder)
end

function main_OPT1_SingleRun_ProduceGraphs()
    benchmarkFolder = joinpath("Benchmarks", "SingleRun")
    CenAstar.OPT1_ProduceBenchmarkingGraphs_V2(benchmarkFolder)
end

function main_OPT1_DAS5_ProduceGraphs()
    benchmarkFolder = joinpath("Das5 Benchmark Data")
    CenAstar.OPT1_ProduceBenchmarkingGraphs_V2(benchmarkFolder)
end

function main_OPT1_DAS5_ProduceReports()
    benchmarkFolder = joinpath("Das5 Benchmark Data")
    OPT1_PrintReports(benchmarkFolder)
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

