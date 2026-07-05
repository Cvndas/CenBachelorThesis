include("Module_CenStar.jl")
using .Module_CenStar
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


function RunThreadcountAsserts()
    threadCount = Threads.nthreads()
    if threadCount != 1
        error("Threadcount is not 1. Start julia with 1 thread when running this function")
    end
end




function main_CenStar_DasBenchmarks()
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
    # if rank == 0
    #     println("Cleared the old benchmarking data in $path")
    # end

    mazeXYs = [100, 200, 500, 1000, 2000, 5000]
    mazeSpecs = []
    for mazeXY in mazeXYs
        push!(mazeSpecs, RandomMazeSpecification(mazeXY, mazeXY))
    end

    runConfig::CenStar_RunConfig = CenStar_RunConfig(mazeSpecs, false, path)
    println("Hello from $processorName on DAS-5, I am rank $rank of $nranks rank")
    Module_CenStar.CenStar_Entry_BenchmarkingRunA(comm, nranks, rank, runConfig)
    MPI.Finalize()
end



#= Run with
include("main.jl"); main_CenStar_SingleRun(_, _);
=#
function main_CenStar_SingleRun(workerCount, mazeXY, multiThread)
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

    if IsDas5()
        println("RUNNING ON DAS-5")

        MPI.Init()
        comm = MPI.Comm_dup(MPI.COMM_WORLD)
        nranks = MPI.Comm_size(comm)
        rank = MPI.Comm_rank(comm)
        masterCore = 0
        processorName = MPI.Get_processor_name()

        randomMazeSpec = RandomMazeSpecification(mazeXY, mazeXY)
        runConfig::CenStar_RunConfig = CenStar_RunConfig([randomMazeSpec], multiThread, path)
        println("Hello from $processorName on DAS-5, I am process $rank of $nranks processes!")

        Module_CenStar.CenStar_Entry_BenchmarkingRunA(comm, nranks, rank, runConfig)

        MPI.Finalize()
    else
        code = quote
            using MPI
            include("Module_CenStar.jl")
            using .Module_CenStar

            config = include("Config.jl")

            randomMazeSpec = RandomMazeSpecification($(mazeXY), $(mazeXY))
            runConfig::CenStar_RunConfig = CenStar_RunConfig([randomMazeSpec], $(multiThread), config.PATH_SingleRun)

            MPI.Init()
            comm = MPI.Comm_dup(MPI.COMM_WORLD)
            nranks = MPI.Comm_size(comm)
            rank = MPI.Comm_rank(comm)
            masterCore = 0
            processorName = MPI.Get_processor_name()
            # println("Hello from $processorName, I am process $rank of $nranks processes!")

            Module_CenStar.CenStar_Entry_BenchmarkingRunA(comm, nranks, rank, runConfig)

            MPI.Finalize()
        end

        run(`$(mpiexec()) -np $(workerCount+1) julia --project=. --threads=2 -e $code`)
    end


end


function main_CenStar_RunA_RunBenchmarks()
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
        include("Module_CenStar.jl")
        using .Module_CenStar

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

        runConfig::CenStar_RunConfig = CenStar_RunConfig(mazeSpecs, false, $(path))
        Module_CenStar.CenStar_Entry_BenchmarkingRunA(comm, nranks, rank, runConfig)

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
function main_CenStar_RunA_ProduceGraphs()
    RunThreadcountAsserts()
    runAFolder = joinpath("Benchmarks", "RunA")
    Module_CenStar.CenStar_ProduceBenchmarkingGraphs_V2(runAFolder)
end

function main_CenStar_SingleRun_ProduceGraphs()
    benchmarkFolder = joinpath("Benchmarks", "SingleRun")
    Module_CenStar.CenStar_ProduceBenchmarkingGraphs_V2(benchmarkFolder)
end

function main_CenStar_DAS5_ProduceGraphs()
    benchmarkFolder = joinpath("Das5 Benchmark Data")
    Module_CenStar.CenStar_ProduceBenchmarkingGraphs_V2(benchmarkFolder)
end

function main_CenStar_DAS5_ProduceReports()
    benchmarkFolder = joinpath("Das5 Benchmark Data")
    CenStar_PrintReports(benchmarkFolder)
end

#= run in the julia repl with
include("main.jl"); main_MPI_ParallelHierarchicSearch_HandcraftedMaps();
=#
function main_CenStar_HandcraftedMaps(mapNames::Vector{String})
    Clear()
    RunThreadcountAsserts()
    println("Started main()")
    code = quote
        using MPI
        include("Module_CenStar.jl")
        using .Module_CenStar

        MPI.Init()
        comm = MPI.Comm_dup(MPI.COMM_WORLD)
        nranks = MPI.Comm_size(comm)
        rank = MPI.Comm_rank(comm)
        processorName = MPI.Get_processor_name()
        masterCore = 0

        multithread = false
        println("Hello from $processorName, I am process $rank of $nranks processes!")
        # Module_CenStar.MPI_Naive_PhsEntry(comm, nranks, rank, host)

        handcraftedMazeSpecs = []
        for mapName in $(mapNames)
            push!(handcraftedMazeSpecs, HandcraftedMazeSpecification(mapName))
        end

        config = include("Config.jl")

        path = "$(config.PATH_LOCAL)_HANDCRAFTEDMAPS_with_$(nranks)_ranks_withScaling_$(config.LEVEL_SCALING)"
        runConfig::CenStar_RunConfig = CenStar_RunConfig(handcraftedMazeSpecs, false, path)

        Module_CenStar.CenStar_Entry_BenchmarkingRunA(comm, nranks, rank, runConfig)
        # Module_CenStar.SingleThreaded_PHS_ReferenceFunc_Entry(comm, nranks, rank, host)
        MPI.Finalize()
    end
    run(`$(mpiexec()) -np 8 julia --project=. -e $code`)
    # run(`$(mpiexec()) -np 4 julia --project=. -e $code`)
    # run(`$(mpiexec()) -np 3 julia --project=. -e $code`)
    # run(`$(mpiexec()) -np 3 julia --project=. -e $code`)
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
        include("Module_CenStar.jl")
        using .Module_CenStar

        MPI.Init()
        comm = MPI.Comm_dup(MPI.COMM_WORLD)
        nranks = MPI.Comm_size(comm)
        rank = MPI.Comm_rank(comm)
        host = MPI.Get_processor_name()
        println("Hello from $host, I am process $rank of $nranks processes!")
        # Module_CenStar.MPI_Naive_PhsEntry(comm, nranks, rank, host)
        Module_CenStar.CenStar_Entry(comm, nranks, rank, host, false)
        # Module_CenStar.SingleThreaded_PHS_ReferenceFunc_Entry(comm, nranks, rank, host)
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
    Module_CenStar.InitializeSeed()
    Module_CenStar.RunMapBuilder(mapToEdit)

    println("Exiting main()")
end


