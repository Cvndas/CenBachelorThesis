using MPI
using DataStructures
# include("OPT1_WorkerEntry.jl")


#=
One very important optimization:

After much benchmarking and eviscerating the previous bottlenecks, I notied that the last worker would triple
the amount of time on its initial path. This worker would never even finish in time to handle a beautification path,
forcing another worker to do 2.

Making the heuristic have more influence completely solves this. However, to keep it fair, that same boost would need
to be applied to the single threaded version.
=#

#=
Another important thing to take note of: It appears that the Astar in this implementation is FASTER than
that of the single threaded astar. It's strange, as the single threaded astar has the benefit of a 2d array
for maptiles that are indexed directly, while this implementation uses a dictionary.

My only guess right now is that because the 2D array in the single threaded is the full thing, cache is 
kind of getting destroyed? But even then, many of the mazes aren't even that big. It's strange.
=#

# Before the following todos, complete the current OPT1 benchmarking.




# Sent by master core for the initial delivery of map data, before any jobs are posted.
const OPT1_MAP_INITIAL_DELIVERY = 0

# Sent by worker core when requesting more map data
const OPT1_MAP_REQUEST = 1

# Sent by the master core in response to a map request 
const OPT1_MAP_SUPPLEMENT = 2

# Sent by the master core to tell the worker which paths to create
const OPT1_INITIAL_JOB_REQUEST = 3

# Sent by the worker to the master, upon completing a path
const OPT1_PATH_DELIVERY_INITIAL_1 = 4
const OPT1_PATH_DELIVERY_INITIAL_2 = 5
const OPT1_PATH_DELIVERY_BEAUTIFIED = 6

const OPT1_BEAUTIFICATION_JOB_REQUEST = 7

const OPT1_WORKER_BENCHMARK_REQUEST = 8
const OPT1_WORKER_BENCHMARK_RESPONSE = 9
const OPT1_WORKER_BENCHMARK_RESPONSE_MUTABLE = 10

const OPT1_ALL_DONE = 11

# // ::: -------------------------:: Structs ::------------------------- ::: // 
#
#
#
struct OPT1_Job
    wayPointA::MapTile
    wayPointB::MapTile
end




struct OPT1_JobRequest
    jobA::OPT1_Job
    jobB::OPT1_Job
    # These are delivered alongside the job for efficiency
    maxX::Int32
    maxY::Int32
end



struct OPT1_MapRequest
    wayPointA::MapTile
    wayPointB::MapTile
    isWayPointA::Bool # used to "level up" how much material the master core will save
    levelUpBoth::Bool
end



mutable struct MinMaxY
    minY::Int32
    maxY::Int32
end


struct AllDone
    all::Bool
    done::Bool
end


mutable struct OPT1_WorkerEntry
    workerRank::Int
    workerLevel_A::Int
    workerLevel_B::Int

    # Initial paths
    solvedPathA::Union{Array{MapTile,1},Nothing}
    solvedPathB::Union{Array{MapTile,1},Nothing}

    # array: for each "column", save the minY and maxY of the mapdata that was sent to the worker.
    sentMinMax::Array{Union{MinMaxY,Nothing}}


    jobA_wayPoints::Tuple{MapTile,MapTile}
    jobB_wayPoints::Tuple{MapTile,MapTile}

    function OPT1_WorkerEntry(workerRank::Int, sentMinMax::Array{Union{MinMaxY,Nothing}}, jobA_wayPoints, jobB_wayPoints)
        new(workerRank, 1, 1, nothing, nothing, sentMinMax, jobA_wayPoints, jobB_wayPoints)
    end
end



mutable struct WorkerPathfindingState
    startTile::MapTile
    endTile::MapTile
    frontier::PriorityQueue{MapTile,Int}
    cameFrom::Dict{MapTile,MapTile}
    costSoFar::Dict{MapTile,Int}
    postponed::Bool
    currentTile::MapTile

    heuristicBooster::Int32

    function WorkerPathfindingState(startTile::MapTile, endTile::MapTile)
        frontier = PriorityQueue{MapTile,Int}()
        frontier[startTile] = 0

        cameFrom = Dict{MapTile,MapTile}()
        cameFrom[startTile] = MapTile(Int32(-99), Int32(-99))

        costSoFar = Dict{MapTile,Int64}()
        costSoFar[startTile] = 0

        new(startTile, endTile, frontier, cameFrom, costSoFar, false, startTile)
    end
end




mutable struct MasterState
    comm
    computedMaze::ComputedMaze
    verticalEstimationSize::Int32
    verticalEstimationSize_Default::Int32

    horizontalExtensionSize::Int32
    horizontalExtensionSize_Default::Int32

    workerEntries::Vector{OPT1_WorkerEntry}
    maxX::Int32
    maxY::Int32
    nranks
    currentLevel

    initialPaths::Vector{Tuple{MapTile,MapTile}}
    solved_initialPaths::Vector{Vector{MapTile}}

    solved_beautyPaths::Vector{Vector{MapTile}}

    initialWayPoints::Vector{MapTile}
    beautifiedWayPoints::Vector{MapTile}

    benchmarkData_Master::BenchmarkData_MasterCore
    iSendRequests::Vector{MPI.Request}

    beautificationJobsToSolve::Deque{Tuple{OPT1_Job,Vector{Int}}} # Vector of high priority workers
    workersReadyToBeautify::Set{Int} # Int is the worker rank

    alreadyCreatedBeautificationJobs::Vector{Int}

    function MasterState(
        comm,
        computedMaze,
        verticalEstimationSize,
        verticalEstimationSize_Default,
        horizontalExtensionSize,
        horizontalExtensionSize_Default,
        maxX,
        maxY,
        nranks,
        currentLevel,
        initialPaths,
        initialWayPoints,
        benchmarkData_Master
    )
        new(comm,
            computedMaze,
            verticalEstimationSize,
            verticalEstimationSize_Default,
            horizontalExtensionSize,
            horizontalExtensionSize_Default,
            Vector{OPT1_WorkerEntry}(),
            maxX,
            maxY,
            nranks,
            currentLevel,
            initialPaths,
            Vector{Vector{MapTile}}(),
            Vector{Vector{MapTile}}(),
            initialWayPoints,
            Vector{MapTile}(),
            benchmarkData_Master,
            Vector{MPI.Request}(),
            Deque{Tuple{OPT1_Job,Vector{Int}}}(),
            Set{Int}(),
            Vector{Int}()
        )
    end
end

# Multicore stuff for the initial solve
mutable struct Worker_MT_Communication
    isDone::Threads.Atomic{Bool}

    pathATilesNecessary::Threads.Atomic{Bool}
    pathATilesReady::Threads.Atomic{Bool}

    pathBTilesNecessary::Threads.Atomic{Bool}
    pathBTilesReady::Threads.Atomic{Bool}

    productionTiles::Vector{MapTile}
    lock_ProductionTiles::ReentrantLock

    lock_MakeSupplementRequest::Threads.ReentrantLock
    cond_MakeSupplementRequest::Threads.ReentrantLock

    readyToStart::Threads.Atomic{Bool}

    function Worker_MT_Communication()
        supplementLock = ReentrantLock()
        supplementCond = Condition(supplementLock)
        new(
            false,
            #
            Atomic{Bool}(false),
            Atomic{Bool}(true),
            #
            Atomic{Bool}(false),
            Atomic{Bool}(true),
            #
            [],
            ReentrantLock(),
            #
            supplementLock,
            supplementCond,
            #
            Atomic{Bool}(false),
        )
    end
end



mutable struct Worker_MT_PathState
    isPathA::Bool
    pathDone::Bool
    pathTilesNecessary::Threads.Atomic{Bool}
    pathTilesReady::Threads.Atomic{Bool}

    function Worker_MT_PathState(isPathA::Bool, c::Worker_MT_Communication)

        if isPathA
            pathTilesNecessary = c.pathATilesNecessary
            pathTilesReady = c.pathATilesReady
        else
            pathTilesNecessary = c.pathBTilesNecessary
            pathTilesReady = c.pathBTilesReady
        end

        new(
            isPathA,
            false,
            pathTilesNecessary,
            pathTilesReady
        )
    end
end


mutable struct WorkerState
    comm
    rank
    availableTiles::Dict{Tuple{Int32,Int32},MapTile}

    maxX::Int32
    maxY::Int32

    jobAState::WorkerPathfindingState
    jobBState::WorkerPathfindingState

    beautyJobState::Union{WorkerPathfindingState,Nothing}
    bench::BenchmarkData_WorkerCore

    # This holds iSend requests, so they aren't garbage collected until the full operation is done
    iSendRequests::Vector{MPI.Request}
end




# // ::: -------------------------:: Miscellanious Functions ::------------------------- ::: // 
#
#
#

function GetMiddleElementOfArray(theArray)
    middle = length(theArray) ÷ 2
    if middle < 1
        middle = 1
    end
    return theArray[middle]
end


function OPT1_TryLevelUp(allEntries::Array{OPT1_WorkerEntry})
    maxLevel = -1
    for entry::OPT1_WorkerEntry in allEntries
        workerLevel = max(entry.workerLevel_A, entry.workerLevel_B)
        if workerLevel > maxLevel
            maxLevel = workerLevel
        end
    end

    return maxLevel
end



function OPT1_WorkerCompletedInitialJob(workerEntry::OPT1_WorkerEntry)
    return workerEntry.solvedPathA !== nothing && workerEntry.solvedPathB !== nothing
end

function OPT1_WorkerCompletedPathBOfInitialJob(workerEntry::OPT1_WorkerEntry)
    return workerEntry.solvedPathB !== nothing
end


function OPT1_UpdateRecord(record::OPT1_WorkerEntry, mapRequest::OPT1_MapRequest)
    if mapRequest.isWayPointA
        record.workerLevel_A += 1
    elseif mapRequest.levelUpBoth
        record.workerLevel_A += 1
        record.workerLevel_B += 1
    else
        record.workerLevel_B += 1
    end
end


function DeduplicateFinalPath(inputPath::Array{MapTile,1})
    asDict = Dict{Tuple{Int32,Int32},MapTile}()
    dupes = 0
    for inputTile in inputPath
        if !haskey(asDict, inputTile)
            asDict[(inputTile.x, inputTile.y)] = inputTile
        else
            dupes += 1
        end
    end
    # println("THERE WERE $dupes DUPLICATES IN THE PATH")

    return inputPath
end


function OPT1_AllInitialSolvedPathsAreReceived(workerRecords::Array{OPT1_WorkerEntry})
    for record::OPT1_WorkerEntry in workerRecords
        if record.solvedPathA === nothing || record.solvedPathB === nothing
            return false
        end
    end
    return true
end



function OPT1_AllBeautyPathsAreReceived(s::MasterState)
    return length(s.solved_beautyPaths) == s.nranks - 1
end



# A function that took quite a few calories to write
function OPT1_GetEstimatedNecessaryCells(wayPointA::MapTile, wayPointB::MapTile, allTiles::Array{MapTile,2}, verticalEstimationSize::Int32, horizontalExtensionSize::Int32, maxX::Int32, maxY::Int32, sentMinMax::Array{Union{MinMaxY,Nothing}})::Array{MapTile,1}
    DEBUG_previouslySentNotAddedCount::Int = 0
    DEBUG_totalConsidered::Int = 0

    # // ::: -------------------------:: Creating the diagonals ::------------------------- ::: // 
    if wayPointA.x < wayPointB.x
        leftWayPoint = wayPointA
        rightWayPoint = wayPointB
    else
        leftWayPoint = wayPointB
        rightWayPoint = wayPointA
    end

    wayPointXDif = rightWayPoint.x - leftWayPoint.x

    # Prevents division by zero when computing slope, if x is equal for left and right
    if wayPointXDif == 0
        wayPointXDif = 1
    end
    slope::Float64 = (rightWayPoint.y - leftWayPoint.y) / wayPointXDif

    diagonals = Tuple{Int32,Int32}[]

    leftMostX = leftWayPoint.x
    leftMostX -= horizontalExtensionSize
    leftMostX = clamp(leftMostX, Int32(1), maxX)

    rightMostX = rightWayPoint.x
    rightMostX += horizontalExtensionSize
    rightMostX = clamp(rightMostX, Int32(1), maxX)


    diagonalY::Float64 = Float64(leftWayPoint.y)

    # Guarantee that the waypoints are included in the package
    push!(diagonals, (leftWayPoint.x, leftWayPoint.y))
    push!(diagonals, (rightWayPoint.x, rightWayPoint.y))

    for x in leftWayPoint.x-1:-1:leftMostX
        push!(diagonals, (x, round(Int32, diagonalY)))
        diagonalY -= slope
    end

    diagonalY = Float64(leftWayPoint.y) + slope
    for x in leftWayPoint.x+1:rightWayPoint.x-1
        push!(diagonals, (x, round(Int32, diagonalY)))
        diagonalY += slope
    end

    diagonalY += slope
    for x in rightWayPoint.x+1:rightMostX
        push!(diagonals, (x, round(Int32, diagonalY)))
        diagonalY += slope
    end


    coordinates::Array{Tuple{Int32,Int32},1} = Tuple{Int32,Int32}[]

    # ::: -------------------------:: Grabbing columns from the diagonals ::------------------------- ::: // 
    for diagonal::Tuple{Int32,Int32} in diagonals

        lowest = diagonal[2] - verticalEstimationSize
        if lowest < 1
            lowest = 1
        end
        if lowest > maxY
            lowest = maxY
        end

        highest = lowest + verticalEstimationSize
        if highest > maxY
            highest = maxY
        end

        columnMinMax = sentMinMax[diagonal[1]]

        if columnMinMax === nothing
            for v in lowest:highest
                @assert v >= 1 "v was less than 1: $v"
                push!(coordinates, (diagonal[1], v))
            end
            newColumnMinMax::MinMaxY = MinMaxY(lowest, highest)
            sentMinMax[diagonal[1]] = newColumnMinMax

        else # If the sentMinMax did exist for this column, use that to selectively gather tiles to send
            @assert columnMinMax.minY > 0
            @assert columnMinMax.maxY > 0
            #=
            These two if checks exist to deal with disjoint ranges. 
            =#
            if highest < columnMinMax.minY
                highest = columnMinMax.minY - 1 # - 1 so we don't send a duplicate
                @assert highest <= maxY "Highest was greater than maxY: $highest vs $maxY, minY was $(columnMinMax.minY)"
            end
            if lowest > columnMinMax.maxY
                lowest = columnMinMax.maxY + 1 # + 1 so we don't send a duplicate
                @assert lowest <= maxY "Lowest was <= maxY ($lowest) after it was originally $(lowest-1)"
            end

            @assert highest >= lowest "highest was smaller than lowest: $highest vs $lowest"
            @assert lowest > 0 "Somehow lowest became less than 1 here: $lowest"

            for v in lowest:highest
                if v < columnMinMax.minY || v > columnMinMax.maxY
                    @assert v >= 1 "v was less than 1: $v. lowest: $lowest, highest: $highest"
                    @assert v <= maxY "v was less than greater than maxY: $v. lowest: $lowest, highest: $highest"
                    push!(coordinates, (diagonal[1], v))
                    DEBUG_totalConsidered += 1
                else
                    DEBUG_previouslySentNotAddedCount += 1
                    DEBUG_totalConsidered += 1
                end
            end

            # Updating the minmax range
            if lowest < columnMinMax.minY
                columnMinMax.minY = lowest
            end
            if highest > columnMinMax.maxY
                columnMinMax.maxY = highest
            end
        end
    end
    mapTilePackage::Array{MapTile,1} = MapTile[]
    for coord in coordinates
        push!(mapTilePackage, allTiles[coord[1], coord[2]])
    end

    return mapTilePackage
end








function OPT1_Entry_BenchmarkingRunA(comm, nranks, rank, masterCore, mazeSizes, singleRun)

    config = include("config.jl")
    if singleRun
        path = config.PATH_SingleRun
    else
        path = config.PATH_BenchmarkingRun_A
    end
    mkpath(path)

    for mazeSizeUniversal in mazeSizes
        mazeSizeX = mazeSizeUniversal
        mazeSizeY = mazeSizeUniversal

        worker::String = if nranks == 2
            "worker"
        else
            "workers"
        end
        if rank == 0
            println("Running BenchmarkingRun A with $(nranks-1) $(worker)")
        end

        reportStructs::Vector{OPT1_BenchmarkingReportStruct} = Vector{OPT1_BenchmarkingReportStruct}()

        config = include("Config.jl")
        iterations = config.AVERAGING_ITERATIONS

        for i in 1:iterations+1
            if rank == 0
                reportStruct::OPT1_BenchmarkingReportStruct = OPT1_Entry(comm, nranks, rank, masterCore, false, mazeSizeX, mazeSizeY)
                if i != 1
                    push!(reportStructs, reportStruct)
                end
            else
                OPT1_Entry(comm, nranks, rank, masterCore, false, mazeSizeX, mazeSizeY)
            end
        end
        if rank == 0
            # println("The AVERAGE report:")
            averageReport = OPT1_AverageBenchmarkingReportStructs(reportStructs)
            println(OPT1_GenerateReportString(averageReport))

            fileName = OPT1_GenerateReportFilename(averageReport)


            filePath = joinpath(path, fileName)
            open(filePath, "w") do file
                serialize(file, averageReport)
            end

            if singleRun
                OPT1_ProduceBenchmarkGraphs(path)
            end

            println("Completed the benchmarking for a maze of size $(mazeSizeX)x$(mazeSizeY) with $(nranks) processors")


        end
    end
end





# // ::: -------------------------:: MPI Functions ::------------------------- ::: // 
#
#
#
function OPT1_Entry(comm, nranks, rank, masterCore, handcraftedTestMap::Bool, mazeSize_X, mazeSize_Y)
    if rank == masterCore
        seed::Int = CenAstar.InitializeSeed()
        mapName::String = ""
        if handcraftedTestMap == true
            # computedMaze::ComputedMaze = LoadMap("DebugMap_1")
            computedMaze::ComputedMaze = LoadMap("BigMap_1")
            # TODO: Proper custom map handling
            mapName = "CustomMap_TODONAMEPARSE"
        else
            width::Int32 = Int32(mazeSize_X)
            height::Int32 = Int32(mazeSize_Y)
            computedMaze = ComputeMaze(width, height)
            mapName = "RandomMap_Seed:$(seed)_Width:$(width)_Height:$(height)"
        end
    end

    MPI.Barrier(comm)

    if rank == masterCore
        reportStruct::OPT1_BenchmarkingReportStruct = OPT1_MasterCore(comm, nranks, computedMaze, mapName)
    else
        OPT1_WorkerCore(comm, nranks, rank, masterCore)
    end

    MPI.Barrier(comm)
    if rank == masterCore
        # println("Press enter to exit")
        # readline()
        # # fig = Figure()
        # println("Done with main().")
        return reportStruct
    end
end





function OPT1_MasterCore(comm, nranks, computedMaze::ComputedMaze, mapName::String)
    T_startTime = time()
    T_startToBeautified::Float64 = @elapsed begin
        T_offlinePrelude::Float64 =
            @elapsed s::MasterState = OPT1_Master_HandleOfflinePrelude(comm, nranks, computedMaze, mapName)
        s.benchmarkData_Master.startTime = T_startTime
        s.benchmarkData_Master.secondsForOfflinePreludeBeforeSendingInitialJobs = T_offlinePrelude

        s.benchmarkData_Master.secondsToSendInitialPathsAndJobsToAllWorkers =
            @elapsed OPT1_Master_SendInitialJobs(s, s.initialPaths)

        OPT1_PreSendMapSupplements(s)

        while OPT1_AllBeautyPathsAreReceived(s) == false
            status = MPI.Probe(comm, MPI.Status; source=MPI.ANY_SOURCE, tag=MPI.ANY_TAG)
            source = MPI.Get_source(status)
            tag = MPI.Get_tag(status)
            # // ::: -------------------------:: Handling a Map supply request ::------------------------- ::: // 
            if tag == OPT1_MAP_REQUEST
                OPT1_Master_HandleMapRequest(s, source)
                s.benchmarkData_Master.timesAMapSupplementWasRequested += 1
                # ::: -------------------------:: Handling an incoming path ::------------------------- ::: // 
            elseif tag == OPT1_PATH_DELIVERY_INITIAL_1 || tag == OPT1_PATH_DELIVERY_INITIAL_2 || tag == OPT1_PATH_DELIVERY_BEAUTIFIED
                OPT1_Master_HandleIncomingSolvedPath(s, status, source, tag)

                if ( # If the benchmark for the completed initial paths hasn't been done yet, and all initial paths are received
                    s.benchmarkData_Master.secondsFromStartToHavingReceivedAllInitialPaths < -1
                    &&
                    OPT1_Master_AllInitialPathsAreReceived(s.workerEntries)
                )
                    s.benchmarkData_Master.secondsFromStartToHavingReceivedAllInitialPaths = time() - s.benchmarkData_Master.startTime
                end
            else
                error("Master received message with tag $tag, which was not expected")
            end
        end

        allDone = AllDone(true, true)

        for i in 1:nranks-1
            MPI.send(allDone, s.comm, dest=i, tag=OPT1_ALL_DONE)
        end

        # It appears that bcast is not ordered with the rest of the messages.
        # MPI.bcast(allDone, s.comm; root=0)
        # println("Broadcasted allDone to all workers")

        # // ::: -------------------------:: Processing the Results ::------------------------- ::: // 
        fullPath_Initial::Array{MapTile,1} = reduce(vcat, s.solved_initialPaths)
        fullPath_Initial = DeduplicateFinalPath(fullPath_Initial)
        fullPath_Beauty::Array{MapTile,1} = reduce(vcat, s.solved_beautyPaths)
        fullPath_Beauty = DeduplicateFinalPath(fullPath_Beauty)
    end # T_startToBeautified

    # Now, let's tell all the workers they're done


    s.benchmarkData_Master.initialPathCost = ComputePathCost(fullPath_Initial)
    s.benchmarkData_Master.beautifiedPathCost = ComputePathCost(fullPath_Beauty)

    initialSolve = SolvedMaze(
        s.computedMaze.allTiles,
        s.computedMaze.mapBorders,
        fullPath_Initial,
        MapTile[],
        MapTile[],
        (s.computedMaze.startTile.x, s.computedMaze.startTile.y),
        (s.computedMaze.endTile.x, s.computedMaze.endTile.y)
    )

    beautySolve = SolvedMaze(
        s.computedMaze.allTiles,
        s.computedMaze.mapBorders,
        fullPath_Beauty,
        MapTile[],
        MapTile[],
        (s.computedMaze.startTile.x, s.computedMaze.startTile.y),
        (s.computedMaze.endTile.x, s.computedMaze.endTile.y)
    )
    fig = Figure(; size=(1600, 900))
    # initialImg = CenAstar.ShowMaze(initialSolve, fig, 1)
    # beautyImg = CenAstar.ShowMaze(beautySolve, fig, 2)

    for iSendRequest::MPI.Request in s.iSendRequests
        MPI.Wait(iSendRequest)
    end

    # // ::: -------------------------:: End of Processing the Results ::------------------------- ::: // 
    for workerRank in 1:nranks-1
        benchmarkRequest = Int64(64)
        MPI.send(benchmarkRequest, s.comm; dest=workerRank, tag=OPT1_WORKER_BENCHMARK_REQUEST)
    end


    workerBenchmarkDatas = Vector{BenchmarkData_WorkerCore}()
    for _ in 1:nranks-1
        workerBenchmarkingEntry = MPI.recv(s.comm, source=MPI.ANY_SOURCE, tag=OPT1_WORKER_BENCHMARK_RESPONSE)
        push!(workerBenchmarkDatas, workerBenchmarkingEntry)
    end

    s.benchmarkData_Master.secondsFromStartToHavingReceivedAllBeautifiedPaths = T_startToBeautified
    s.benchmarkData_Master.finalLevel = s.currentLevel
    s.benchmarkData_Master.finalSize = s.horizontalExtensionSize * s.verticalEstimationSize

    # Limitation here is that maxX and maxY have to be different from previous mazes for this to be correct
    stSeconds = @elapsed stSolution = st_AStar(s.computedMaze.startTile, s.computedMaze.endTile, s.computedMaze.allTiles)
    stCost = ComputePathCost(stSolution)
    # println("The single threaded solve for a maze of $(s.maxX), $(s.maxY) was freshly computed")




    reportStruct::OPT1_BenchmarkingReportStruct = OPT1_GenerateBenchmarkReport(s.benchmarkData_Master, workerBenchmarkDatas, stCost, stSeconds)

    return reportStruct
end














function OPT1_Master_HandleOfflinePrelude(comm, nranks, computedMaze::ComputedMaze, mapName::String)

    # Magic values to tune for good results 

    # verticalEstimationSize_Default::Int32 = 99999999
    # horizontalExtensionSize_Default::Int32 = 99999999

    # verticalEstimationSize_Default::Int32 = 16
    # horizontalExtensionSize_Default::Int32 = 16

    verticalEstimationSize_Default::Int32 = 32
    horizontalExtensionSize_Default::Int32 = 16

    # verticalEstimationSize_Default::Int32 = 64
    # horizontalExtensionSize_Default::Int32 = 32


    currentLevel = 1

    verticalEstimationSize::Int32 = verticalEstimationSize_Default
    horizontalExtensionSize::Int32 = horizontalExtensionSize_Default

    maxX::Int32 = Int32(size(computedMaze.allTiles, 1))
    maxY::Int32 = Int32(size(computedMaze.allTiles, 2))

    # Let's first generate some waypoints, as these determine what data the workers need
    initialWayPoints::Array{MapTile} = []
    if length(computedMaze.optionalWaypoints) == 0
        initialWayPoints = GenerateInitialWaypoints(computedMaze.startTile, computedMaze.endTile, (nranks - 1) * 2, computedMaze.allTiles)
    else
        initialWayPoints = GenerateCoreAppropriateWaypoints(computedMaze.optionalWaypoints, computedMaze.allTiles, nranks)
    end

    initialPaths::Vector{Tuple{MapTile,MapTile}} = Tuple{MapTile,MapTile}[]
    for i in 1:length(initialWayPoints)-1
        push!(initialPaths, (initialWayPoints[i], initialWayPoints[i+1]))
    end

    mapSize::Int = length(computedMaze.allTiles)
    initialMapDeliverySize::Int = Int(verticalEstimationSize * horizontalExtensionSize)
    benchmarkData_Master = BenchmarkData_MasterCore(
        mapName,
        nranks - 1,
        mapSize,
        initialMapDeliverySize
    )

    s::MasterState = MasterState(
        comm,
        computedMaze,
        verticalEstimationSize,
        verticalEstimationSize_Default,
        horizontalExtensionSize,
        horizontalExtensionSize_Default,
        maxX,
        maxY,
        nranks,
        currentLevel,
        initialPaths,
        initialWayPoints,
        benchmarkData_Master
    )
    return s
end


# Sends from worker 1 to last worker
# function OPT1_Master_SendInitialJobs(s::MasterState, paths::Vector{Tuple{MapTile,MapTile}})
#     pathIndex = 1
#     @assert length(paths) == 2 * (s.nranks - 1) "length of paths was $(length(paths)) and rhs was $(2*(s.nranks - 1))"
#     for i in 1:s.nranks-1 # for each rank
#         pathA = paths[pathIndex]

#         sentMinMax::Array{Union{MinMaxY,Nothing}} = fill(nothing, s.maxX)

#         pathA_estimatedNecessaryCells::Array{MapTile,1} =
#             OPT1_GetEstimatedNecessaryCells(pathA[1], pathA[2], s.computedMaze.allTiles, s.verticalEstimationSize, s.horizontalExtensionSize, s.maxX, s.maxY, sentMinMax)
#         pathIndex += 1

#         pathB = paths[pathIndex]
#         pathB_estimatedNecessaryCells::Array{MapTile,1} =
#             OPT1_GetEstimatedNecessaryCells(pathB[1], pathB[2], s.computedMaze.allTiles, s.verticalEstimationSize, s.horizontalExtensionSize, s.maxX, s.maxY, sentMinMax)
#         pathIndex += 1

#         both_estimatedNecessaryCells::Array{MapTile,1} = unique(vcat(pathA_estimatedNecessaryCells, pathB_estimatedNecessaryCells))

#         workerRank = i

#         # mapDataForWorker::OPT1_PhsMapData = OPT1_PhsMapData(both_estimatedNecessaryCells)
#         push!(s.iSendRequests, MPI.Isend(both_estimatedNecessaryCells, s.comm; dest=workerRank, tag=OPT1_MAP_INITIAL_DELIVERY))

#         jobA::OPT1_Job = OPT1_Job(pathA[1], pathA[2])
#         jobB::OPT1_Job = OPT1_Job(pathB[1], pathB[2])
#         jobsForWorker::OPT1_JobRequest = OPT1_JobRequest(jobA, jobB, s.maxX, s.maxY)

#         push!(s.iSendRequests, MPI.Isend(jobsForWorker, s.comm; dest=workerRank, tag=OPT1_INITIAL_JOB_REQUEST))


#         push!(s.workerEntries, OPT1_WorkerEntry(workerRank, sentMinMax, pathA, pathB))
#     end
# end

# Sends from last worker to first worker
function OPT1_Master_SendInitialJobs(s::MasterState, paths::Vector{Tuple{MapTile,MapTile}})
    pathIndex = length(paths)
    @assert length(paths) == 2 * (s.nranks - 1) "length of paths was $(length(paths)) and rhs was $(2*(s.nranks - 1))"
    for i in (s.nranks-1):-1:1

        sentMinMax::Array{Union{MinMaxY,Nothing}} = fill(nothing, s.maxX)

        pathB = paths[pathIndex]
        pathB_estimatedNecessaryCells::Array{MapTile,1} =
            OPT1_GetEstimatedNecessaryCells(pathB[1], pathB[2], s.computedMaze.allTiles, s.verticalEstimationSize, s.horizontalExtensionSize, s.maxX, s.maxY, sentMinMax)

        pathIndex -= 1
        pathA = paths[pathIndex]
        pathA_estimatedNecessaryCells::Array{MapTile,1} =
            OPT1_GetEstimatedNecessaryCells(pathA[1], pathA[2], s.computedMaze.allTiles, s.verticalEstimationSize, s.horizontalExtensionSize, s.maxX, s.maxY, sentMinMax)
        pathIndex -= 1


        both_estimatedNecessaryCells::Array{MapTile,1} = unique(vcat(pathA_estimatedNecessaryCells, pathB_estimatedNecessaryCells))

        workerRank = i

        # mapDataForWorker::OPT1_PhsMapData = OPT1_PhsMapData(both_estimatedNecessaryCells)
        push!(s.iSendRequests, MPI.Isend(both_estimatedNecessaryCells, s.comm; dest=workerRank, tag=OPT1_MAP_INITIAL_DELIVERY))

        jobA::OPT1_Job = OPT1_Job(pathA[1], pathA[2])
        jobB::OPT1_Job = OPT1_Job(pathB[1], pathB[2])
        jobsForWorker::OPT1_JobRequest = OPT1_JobRequest(jobA, jobB, s.maxX, s.maxY)

        push!(s.iSendRequests, MPI.Isend(jobsForWorker, s.comm; dest=workerRank, tag=OPT1_INITIAL_JOB_REQUEST))


        push!(s.workerEntries, OPT1_WorkerEntry(workerRank, sentMinMax, pathA, pathB))
    end
    reverse!(s.workerEntries)
end


function OPT1_PreSendMapSupplements(s::MasterState)
    for worker in s.workerEntries
        # Leveling up path A
        virtualMapRequest_A::OPT1_MapRequest = OPT1_MapRequest(worker.jobA_wayPoints[1], worker.jobA_wayPoints[2], true, false)
        virtualMapRequest_B::OPT1_MapRequest = OPT1_MapRequest(worker.jobB_wayPoints[1], worker.jobB_wayPoints[2], false, false)
        OPT1_Master_RespondToMapRequest(s, virtualMapRequest_A, worker.workerRank)
        OPT1_Master_RespondToMapRequest(s, virtualMapRequest_B, worker.workerRank)
    end
end


function OPT1_Master_HandleMapRequest(s::MasterState, source)
    mapRequest_ref = Ref{OPT1_MapRequest}()
    MPI.Recv!(mapRequest_ref, s.comm; source=source, tag=OPT1_MAP_REQUEST)
    mapRequest::OPT1_MapRequest = mapRequest_ref[]
    OPT1_Master_RespondToMapRequest(s, mapRequest, source)
end



function OPT1_Master_RespondToMapRequest(s::MasterState, mapRequest::OPT1_MapRequest, source)
    OPT1_UpdateRecord(s.workerEntries[source], mapRequest)
    s.currentLevel = OPT1_TryLevelUp(s.workerEntries)

    s.verticalEstimationSize = s.verticalEstimationSize_Default * (s.currentLevel * 3)
    s.horizontalExtensionSize = s.horizontalExtensionSize_Default * (s.currentLevel * 3)


    sentMinMax::Array{Union{MinMaxY,Nothing}} = s.workerEntries[source].sentMinMax
    supplementMapTiles::Array{MapTile,1} =
        OPT1_GetEstimatedNecessaryCells(mapRequest.wayPointA, mapRequest.wayPointB, s.computedMaze.allTiles, s.verticalEstimationSize, s.horizontalExtensionSize, s.maxX, s.maxY, sentMinMax)

    req = MPI.Isend(supplementMapTiles, s.comm, dest=source, tag=OPT1_MAP_SUPPLEMENT)
    push!(s.iSendRequests, req)
end







function OPT1_SendBeautificationJob(s::MasterState, worker::Int, job::OPT1_Job)
    req = MPI.Isend(job, s.comm; dest=worker, tag=OPT1_BEAUTIFICATION_JOB_REQUEST)
    push!(s.iSendRequests, req)

end




function OPT1_Master_AllInitialSecondPathsAreReceived(workerEntries::Array{OPT1_WorkerEntry})::Bool
    for workerEntry::OPT1_WorkerEntry in workerEntries
        if workerEntry.solvedPathB !== nothing
            continue
        else
            return false
        end
    end
    return true
end




function OPT1_Master_AllInitialPathsAreReceived(workerEntries::Array{OPT1_WorkerEntry})::Bool
    for workerEntry::OPT1_WorkerEntry in workerEntries
        if workerEntry.solvedPathA === nothing
            return false
        elseif workerEntry.solvedPathB === nothing
            return false
        end
    end
    return true
end




function OPT1_Master_TryCreatingBeautificationJobs(s::MasterState)

    #= --- The recipe for creating Beautification Jobs
    The beautifcation paths:
    For the first worker, it starts at the start of the own first path
    and ends at the middle of the own second path.

    For middle workers, it starts at the middle of the previous worker's second path,
    and ends at the middle of the own second path

    For the last worker, it starts at the middle of the previous worker's second path,
    and ends at the end of the own second path
    =#


    jobWasCreated::Bool = true
    while jobWasCreated == true
        jobId = 0
        jobWasCreated = false
        for worker::OPT1_WorkerEntry in s.workerEntries
            jobId += 1
            jobWasAlreadyCreatedBefore = false
            for previouslyMadeBeautificationJob in s.alreadyCreatedBeautificationJobs
                if jobId == previouslyMadeBeautificationJob
                    jobWasAlreadyCreatedBefore = true
                end
            end
            if jobWasAlreadyCreatedBefore
                continue
            end

            # For all workers, we are dependent of the personal A and B paths to be done. Check the recipe above to see why
            if worker.solvedPathA === nothing || worker.solvedPathB === nothing
                continue
            end

            highPriorityJob::Bool = false

            rank = worker.workerRank
            isOnlyWorker::Bool = rank == 1 && s.nranks == 2

            isFirstWorker::Bool = rank == 1
            isEndWorker::Bool = rank == s.nranks - 1
            isMiddleWorker::Bool = !isFirstWorker && !isEndWorker

            if isOnlyWorker
                beautyStartTile::MapTile = worker.solvedPathA[end]
                beautyEndTile::MapTile = worker.solvedPathB[1]

            elseif isFirstWorker
                beautyStartTile = worker.solvedPathA[end]
                beautyEndTile = GetMiddleElementOfArray(worker.solvedPathB)

            elseif isMiddleWorker
                prev::OPT1_WorkerEntry = s.workerEntries[rank-1]

                # For middle workers, we are dependent on the previous worker having finished the second path. If it's 
                # not done, we skip.
                if prev.solvedPathB === nothing
                    continue
                end

                beautyStartTile = GetMiddleElementOfArray(prev.solvedPathB)
                beautyEndTile = GetMiddleElementOfArray(worker.solvedPathB)

            elseif isEndWorker
                prev = s.workerEntries[rank-1]

                # Like with middle workers, we are dependent on the previous worker having finished the second path
                if prev.solvedPathB === nothing
                    continue
                end
                beautyStartTile = GetMiddleElementOfArray(prev.solvedPathB)
                beautyEndTile = worker.solvedPathB[1]

                # The job created by the end worker is (currently) longer than the others, so it's high priority. It'll skip 
                # the queue
                highPriorityJob = true

            else
                error("None were true, of isFirstWorker, isEndWorker, and isMiddleWorker")
            end

            beautificationJob = OPT1_Job(beautyStartTile, beautyEndTile)
            priorityWorkers = [rank]
            if rank > 1
                push!(priorityWorkers, rank - 1)
            end

            # All the checks passed. Let's submit the job to the queue 
            jobWasCreated = true
            if highPriorityJob
                pushfirst!(s.beautificationJobsToSolve, (beautificationJob, priorityWorkers))
            else
                push!(s.beautificationJobsToSolve, (beautificationJob, priorityWorkers))
            end
            # println("Master created another beautification job")

            push!(s.alreadyCreatedBeautificationJobs, jobId)
        end
    end
end




function OPT1_Master_HandleIncomingSolvedPath(s::MasterState, status::MPI.MPI_Status, source, tag)
    # Receive path over MPI. Status guaranteed that something is present.
    incomingPathSize = MPI.Get_count(status, MapTile)
    receivedPath = Array{MapTile,1}(undef, incomingPathSize)
    incomingPath_MPIRequest = MPI.Irecv!(receivedPath, s.comm; source=source, tag=tag)
    MPI.Wait(incomingPath_MPIRequest)

    if tag == OPT1_PATH_DELIVERY_INITIAL_1
        @assert s.workerEntries[source].solvedPathA === nothing "Core $source sent solved path A, but this was already solved"
        s.workerEntries[source].solvedPathA = receivedPath
    elseif tag == OPT1_PATH_DELIVERY_INITIAL_2
        @assert s.workerEntries[source].solvedPathB === nothing "Core $source sent solved path B, but this was already solved"
        s.workerEntries[source].solvedPathB = receivedPath

        if s.benchmarkData_Master.firstWorkerIdToCompleteSecondInitialPath == BenchmarkValue_NOTSET
            s.benchmarkData_Master.firstWorkerIdToCompleteSecondInitialPath = source
        end
        if OPT1_Master_AllInitialSecondPathsAreReceived(s.workerEntries)
            s.benchmarkData_Master.lastWorkerIdToCompleteSecondInitialPath = source
        end

    elseif tag == OPT1_PATH_DELIVERY_BEAUTIFIED
        push!(s.solved_beautyPaths, receivedPath)

        # After delivering a beuatificaiton path, the worker once again becomes available to do more work.
        # Since the worker is now free once again, maybe there's another beautification job to solve. Let's try!
        push!(s.workersReadyToBeautify, source)
        OPT1_Master_TrySendingBeautificationJobs(s)

        # // ::: -------------------------:: Early return here ::------------------------- ::: // 
        return
    else
        error("Received incompatible tag in HandleIncomingInitialSolvedPath: $tag")
    end

    # The beautification delivery had an early return. Everything from here on is guaranteed to be processing an
    # initial path delivery

    push!(s.solved_initialPaths, receivedPath)

    firstPathReceived::Bool = s.workerEntries[source].solvedPathA !== nothing
    secondPathReceived::Bool = s.workerEntries[source].solvedPathB !== nothing
    bothPathsReceived::Bool = firstPathReceived && secondPathReceived

    # We only move ourselves to beautification if both initial paths are done
    if bothPathsReceived
        push!(s.workersReadyToBeautify, source)
        # println("Worker $source is ready to receive a beautification job")
    end
    OPT1_Master_TryCreatingBeautificationJobs(s)
    OPT1_Master_TrySendingBeautificationJobs(s)
end





function OPT1_Master_TrySendingBeautificationJobs(s::MasterState)
    while true
        mustSendBeautificationJob::Bool = !isempty(s.workersReadyToBeautify) && !isempty(s.beautificationJobsToSolve)
        if mustSendBeautificationJob
            (beautificationJobToSolve, priorityWorkers) = popfirst!(s.beautificationJobsToSolve)
            theChosenOne = -1
            for priorityWorker in priorityWorkers
                if priorityWorker in s.workersReadyToBeautify
                    s.benchmarkData_Master.numberOfTimesPriorityWorkerWasChosenForBeautification += 1
                    theChosenOne = pop!(s.workersReadyToBeautify, priorityWorker)
                    break
                end
            end
            if theChosenOne < 0
                theChosenOne = pop!(s.workersReadyToBeautify)
            end

            # println("master chose to send a beautification job to $workerToSolveBeautificationJob")

            OPT1_SendBeautificationJob(s, theChosenOne, beautificationJobToSolve)
            continue
        else
            break
        end
    end
end


















function OPT1_WorkerCore(comm, nranks, rank, masterCore)
    T_startTime = time()
    w::WorkerState = OPT1_Worker_ReceiveInitialMapDataAndJobs(comm, rank)
    w.bench.startTime = T_startTime
    w.bench.timeOfReceivingInitialJob = time()

    # The single threaded initial job solve 
    # OPT1_Worker_CompleteJobPair(w, OPT1_PATH_DELIVERY_INITIAL_1, OPT1_PATH_DELIVERY_INITIAL_2)

    # The multithreaded initial job solve
    OPT1_Worker_MT_SolveInitialJobs(w)

    w.bench.timeOfFinishingInitialJob = time()
    w.bench.secondsFromReceivingJobToHavingSentInitialPaths = time() - w.bench.timeOfReceivingInitialJob

    # Now the second phase: Beautification, or map

    OPT1_Worker_BeautificationPhase(w)

    # println("The worker is done with the beautification phase (did $(w.bench.numberOfBeautificationJobsCompleted) beautification jobs)")

    w.bench.solvingBeautifiedPathAfterReceivingBeautificationJob = time() - w.bench.timeOfReceivingBeauticationJob
    w.bench.secondsFromReceivingJobToHavingSentBeautifiedPaths = time() - w.bench.timeOfReceivingInitialJob

    # Wait until we receive a benchmarking request from the master. We don't want to pollute MPI
    # when other workers are still busy.
    # benchmarkingRequestStatus = MPI.Probe(comm, MPI.Status, source=masterCore, tag=OPT1_WORKER_BENCHMARK_REQUEST)

    # benchmarkingRequestBuffer_ref = Ref{OPT1_WorkerBenchmarkingDataRequest}()

    benchmarkingRequestBuffer = Vector{Int64}
    benchmarkingRequestBuffer = MPI.recv(comm; source=masterCore, tag=OPT1_WORKER_BENCHMARK_REQUEST)

    MPI.send(w.bench, comm; dest=masterCore, tag=OPT1_WORKER_BENCHMARK_RESPONSE)

    for iSendRequest::MPI.Request in w.iSendRequests
        MPI.Wait(iSendRequest)
    end
end





function OPT1_Worker_SendMapRequest(jobState::WorkerPathfindingState, isWayPointA::Bool, comm, w::WorkerState; isBeauty=false)
    mapRequest::OPT1_MapRequest = OPT1_MapRequest(jobState.startTile, jobState.endTile, isWayPointA, isBeauty)
    sendRequest::MPI.Request = MPI.Isend(mapRequest, comm, dest=0, tag=OPT1_MAP_REQUEST)
    push!(w.iSendRequests, sendRequest)
end


function OPT1_Worker_SendCompletedPath(solvedPath::Array{MapTile}, TAG_TO_USE, comm, w::WorkerState)
    push!(w.iSendRequests, MPI.Isend(solvedPath, comm, dest=0, tag=TAG_TO_USE))
end



function OPT1_Worker_ReceiveAndProcessMapSupplement!(w::WorkerState)
    comm = w.comm
    availableTiles = w.availableTiles
    rank = w.rank

    isMessageAvailable, mapSupplyStatus::MPI.Status = MPI.Iprobe(comm, MPI.Status, ; source=0, tag=OPT1_MAP_SUPPLEMENT)
    if isMessageAvailable == false
        T_waitingForDataToComeIn = time()
        w.bench.numberOfOccasionsMapDataWasNotAvailableAndIHadToWait += 1
        mapSupplyStatus = MPI.Probe(comm, MPI.Status, source=0, tag=OPT1_MAP_SUPPLEMENT)
        w.bench.secondsSpentWaitingForMapDataToComeIn += (time() - T_waitingForDataToComeIn)
    end

    T_startOfReceivingMapSupplement = time()

    incomingTilesSize = MPI.Get_count(mapSupplyStatus, MapTile)
    mapSupplyDelivery = Array{MapTile,1}(undef, incomingTilesSize)
    MPI.Recv!(mapSupplyDelivery, comm; source=0, tag=OPT1_MAP_SUPPLEMENT)

    w.bench.secondsReceivingIncomingMapSupplements += time() - T_startOfReceivingMapSupplement

    T_startOfProcessingMapSupplement = time()
    for suppliedTile::MapTile in mapSupplyDelivery
        @assert !haskey(availableTiles, (suppliedTile.x, suppliedTile.y)) "Worker $rank already had the tile $suppliedTile in its storage"
        availableTiles[(suppliedTile.x, suppliedTile.y)] = suppliedTile
    end
    w.bench.secondsProcessingIncomingMapSupplements += time() - T_startOfProcessingMapSupplement
end





function OPT1_Worker_BeautificationPhase(w::WorkerState)
    #=
    In the beautification phase, we can receive 3 types of messages:
    1. A beautification job
    2. A map supplement
    3. An AllDone message
    =#
    hasBeautificationJob::Bool = false
    while true
        status = MPI.Probe(w.comm, MPI.Status; source=0, tag=MPI.ANY_TAG)
        tag = MPI.Get_tag(status)


        if tag == OPT1_BEAUTIFICATION_JOB_REQUEST
            # Only measure the first time this happens
            if w.bench.waitingForBeautificationJobAfterSolvingInitial < -1
                w.bench.waitingForBeautificationJobAfterSolvingInitial = time() - w.bench.timeOfFinishingInitialJob
                w.bench.timeOfReceivingBeauticationJob = time()
            end

            OPT1_Worker_ReceiveBeautificationJobs!(w)
            # println("Worker $(w.rank) received a beautification job")
            hasBeautificationJob = true

            #= 
            Interesting fact:
            Due to the "Always One Step Ahead" optimization for the master core,
                when a worker enters this function, this supplement, which was not actually
                requested by the worker, is the first thing that will be read,
                as it was already sitting in the queue, whereas the beautification job
                still needs to be sent. This also ensures that during beautification, the chance
                that a worker needs to request more data is even smaller
            =#
        elseif tag == OPT1_MAP_SUPPLEMENT
            OPT1_Worker_ReceiveAndProcessMapSupplement!(w)

        elseif tag == OPT1_ALL_DONE
            MPI.recv(w.comm)
            break
        else
            error("Not handling tag $tag in the beautification phase")
        end

        if hasBeautificationJob
            OPT1_Worker_CompleteBeautyJob(w)
            # println("Worker $(w.rank) completed a beautification job")
            w.bench.numberOfBeautificationJobsCompleted += 1
            hasBeautificationJob = false
        end
    end



end


function OPT1_Worker_ReceiveBeautificationJobs!(w::WorkerState)
    # beautyJob_Ref = Ref{OPT1_Job}()
    # beautyJob_MPI_Request = MPI.Irecv!(beautyJob_Ref, w.comm; source=0, tag=OPT1_BEAUTIFICATION_JOB_REQUEST)
    # MPI.Wait(beautyJob_MPI_Request)
    # beautyJob::OPT1_Job = beautyJob_Ref[]

    beautyJobRef = Ref{OPT1_Job}()
    MPI.Recv!(beautyJobRef, w.comm; source=0, tag=OPT1_BEAUTIFICATION_JOB_REQUEST)
    beautyJob = beautyJobRef[]


    startTuple = (beautyJob.wayPointA.x, beautyJob.wayPointA.y)
    endTuple = (beautyJob.wayPointB.x, beautyJob.wayPointB.y)

    while (!haskey(w.availableTiles, startTuple) || !haskey(w.availableTiles, endTuple))
        mapRequest::OPT1_MapRequest = OPT1_MapRequest(beautyJob.wayPointA, beautyJob.wayPointB, false, true)
        push!(w.iSendRequests, MPI.Isend(mapRequest, w.comm, dest=0, tag=OPT1_MAP_REQUEST))
        OPT1_Worker_ReceiveAndProcessMapSupplement!(w)
    end

    beauty_startTile = w.availableTiles[startTuple]
    beauty_endTile = w.availableTiles[endTuple]

    w.beautyJobState = WorkerPathfindingState(beauty_startTile, beauty_endTile)
end




function OPT1_Worker_ReceiveInitialMapDataAndJobs(comm, rank)::WorkerState
    # # The first thing we expect is the initial path delivery
    # The map data is sent first, but we can open up the mailbos for the job request in the meantime
    initialJobRequest_Ref = Ref{OPT1_JobRequest}()
    initialJobRequest_MPIRequest = MPI.Irecv!(initialJobRequest_Ref, comm; source=0, tag=OPT1_INITIAL_JOB_REQUEST)

    initialMapDataDelivery_Status = MPI.Probe(comm, MPI.Status, source=0, tag=OPT1_MAP_INITIAL_DELIVERY)
    mapDataCount = MPI.Get_count(initialMapDataDelivery_Status, MapTile)

    initialMapDataDelivery = Array{MapTile,1}(undef, mapDataCount)

    MPI.Recv!(initialMapDataDelivery, comm; source=0, tag=OPT1_MAP_INITIAL_DELIVERY)

    # This is probably very slow.
    availableTiles::Dict{Tuple{Int32,Int32},MapTile} = Dict{Tuple{Int32,Int32},MapTile}()
    for tile::MapTile in initialMapDataDelivery
        availableTiles[(tile.x, tile.y)] = tile
    end

    MPI.Wait(initialJobRequest_MPIRequest)
    initialJobRequest::OPT1_JobRequest = initialJobRequest_Ref[]
    jobA::OPT1_Job = initialJobRequest.jobA
    jobB::OPT1_Job = initialJobRequest.jobB

    maxX::Int32 = initialJobRequest.maxX
    maxY::Int32 = initialJobRequest.maxY

    # println("The tiles the worker received for the initial job: ")
    # display(availableTiles)

    jobA_startTile = availableTiles[(jobA.wayPointA.x, jobA.wayPointA.y)]
    jobA_endTile = availableTiles[(jobA.wayPointB.x, jobA.wayPointB.y)]

    jobB_startTile = availableTiles[(jobB.wayPointA.x, jobB.wayPointA.y)]
    jobB_endTile = availableTiles[(jobB.wayPointB.x, jobB.wayPointB.y)]

    jobAState::WorkerPathfindingState = WorkerPathfindingState(jobA_startTile, jobA_endTile)
    jobBState::WorkerPathfindingState = WorkerPathfindingState(jobB_startTile, jobB_endTile)

    workerBenchmarking = BenchmarkData_WorkerCore(
        rank
    )
    w::WorkerState = WorkerState(comm, rank, availableTiles, maxX, maxY, jobAState, jobBState, nothing, workerBenchmarking, Vector{MPI.Request}())
    return w
end




function OPT1_Worker_CompleteBeautyJob(w::WorkerState)
    beautyJobSolved::Bool = false
    while beautyJobSolved == false
        T_beforeComputation = time()
        jobSolveResult = OPT1_CustomAStar(w, w.beautyJobState)
        w.bench.rawComputationSeconds_Beautify += time() - T_beforeComputation
        if jobSolveResult === nothing
            # Request for more data to come in, and wait for it
            w.bench.numberOfTimesNewMapDataWasRequested += 1
            OPT1_Worker_SendMapRequest(w.beautyJobState, false, w.comm, w; isBeauty=true)
            w.beautyJobState.postponed = true
            OPT1_Worker_ReceiveAndProcessMapSupplement!(w)
        else
            beautyJobSolved = true
            OPT1_Worker_SendCompletedPath(jobSolveResult, OPT1_PATH_DELIVERY_BEAUTIFIED, w.comm, w)
        end
    end
end




function OPT1_Worker_MT_SolveInitialJobs(w::WorkerState)
    c = Worker_MT_Communication()

    @assert Threads.nthreads() > 1 "Didn't have enough threads for MT_SolveInitialJobs(): $(Threads.nthreads())"

    # T_StartingMPIThread = time()
    @spawn OPT1_Worker_MT_MPIThread(w, c)


    println("$(w.rank) entered MT_SolveInitialJobs()")
    error("TODO: Implement the rest tomorrow, based on the pseudo implementation")
end



function OPT1_Worker_MT_MPIThread(w::WorkerState, c::Worker_MT_Communication)
    lock(c.lock_MakeSupplementRequest)
    c.readyToStart[] = true
    waitingForSupplement_A = false
    waitingForSupplement_B = false
    while true
        isBusyWaiting = false
        while waitingForSupplement_A || waitingForSupplement_B
            # If NOT both, we can do a blocking read. We don't have to busy wait
            if !(waitingForSupplement_A && waitingForSupplement_B)
                isBusyWaiting = false
            end

            # TODO: Function for doing this processing for either path. Only thing that's different is the
            # setting of the boolean waitingForSupplement_X that comes after.
            if waitingForSupplement_A
                # TODO: MPI Iprobe thing. 
                localProductionTiles::Vector{MapTile} = OPT1_Worker_MT_ReadIncomingMapSupplement()
                lock(c.lock_ProductionTiles)
                unlock(c.lock_ProductionTiles)
                waitingForSupplement_A = false
                # And AFTER receiving the data, we can lock the production tiles, update what it points to,
                # and then notify the pathfinder thread
            end
            if waitingForSupplement_B
                # TODO: Iprobe thing
            end
            if isBusyWaiting
                yield()
            end
        end
        error("TODO: Implement based on pseudo implementation")
    end

end



function OPT1_Worker_MT_PathfindingThread(w::WorkerState)
    a = Worker_MT_PathState(true, c)
    b = Worker_MT_PathState(false, c)

    while c.readyToStart[] == false
        yield()
    end
    while true
        OPT1_Worker_MT_RunPathfinding(w, a)
        OPT1_Worker_MT_RunPathfinding(w, b)
        bothDone = a.pathDone && b.pathDone
        if bothDone
            lock(c.lock_MakeSupplementRequest)
            notify(c.cond_MakeSupplementRequest)
            unlock(c.lock_MakeSupplementRequest)
            println("MT Pathfinder: We're done!")
            break
        end
    end

    # TODO: Handle these benchmarking values when the alg is properly implemented
    # T_waitingForMpiThreadToGetReady = time() - T_StartingMPIThread
    # Debug.Log("Waiting for the MPI thread to get ready took $(T_waitingForMpiThreadToGetReady) seconds. TODO: Put into the benchmarks")

    error("TODO: Implement based on pseudo implementation")
end


function OPT1_Worker_MT_RunPathfinding(w::WorkerState, p::Worker_MT_PathState)
    error("TODO: Implement based on pseudo implementation")
end




function OPT1_Worker_CompleteJobPair(w::WorkerState, jobACompletionTag, jobBCompletionTag)
    jobASolved::Bool = false
    jobBSolved::Bool = false

    T_jobPairStart = time()
    timeSpentWorking = 0

    while !jobASolved || !jobBSolved

        if !jobASolved
            # Check if Job A's supplement has come in the mail yet.
            if w.jobAState.postponed
                OPT1_Worker_ReceiveAndProcessMapSupplement!(w)
            end
            T_beforeComputation = time()
            jobA_solveResult = OPT1_CustomAStar(w, w.jobAState)
            timeSpentWorking += time() - T_beforeComputation

            w.bench.rawComputationSeconds_Initial += time() - T_beforeComputation
            if jobA_solveResult === nothing
                w.bench.numberOfTimesNewMapDataWasRequested += 1
                OPT1_Worker_SendMapRequest(w.jobAState, true, w.comm, w)
                w.jobAState.postponed = true
            else
                jobASolved = true
                OPT1_Worker_SendCompletedPath(jobA_solveResult, jobACompletionTag, w.comm, w)
            end

        end


        if !jobBSolved

            # Check if Job B's supplement has come in the mail yet 
            if w.jobBState.postponed
                OPT1_Worker_ReceiveAndProcessMapSupplement!(w)
            end
            T_beforeComputation = time()
            jobB_solveResult = OPT1_CustomAStar(w, w.jobBState)
            timeSpentWorking += time() - T_beforeComputation

            w.bench.rawComputationSeconds_Initial += time() - T_beforeComputation
            if jobB_solveResult === nothing
                w.bench.numberOfTimesNewMapDataWasRequested += 1
                OPT1_Worker_SendMapRequest(w.jobBState, false, w.comm, w)
                w.jobBState.postponed = true
            else
                jobBSolved = true
                OPT1_Worker_SendCompletedPath(jobB_solveResult, jobBCompletionTag, w.comm, w)
            end

        end

    end

    w.bench.secondsNotSpentDoingWorkInInitialPath = time() - T_jobPairStart - timeSpentWorking

end





















# // ::: -------------------------:: PATHFINDING ::------------------------- ::: // 
#
#
#
#

function AStar_OPT1_GetNeighbors!(wState::WorkerState, neighbors::Array{MapTile}, pathfindingState::WorkerPathfindingState)::Bool
    # Returns nothing when a tile is missing, and the master core needs to supply it for us.
    empty!(neighbors)
    northY = pathfindingState.currentTile.y + 1
    if northY <= wState.maxY
        northX = pathfindingState.currentTile.x
        north = get(wState.availableTiles, (northX, northY), nothing)
        if north === nothing
            return false
        end
        push!(neighbors, north)
    end

    eastX = pathfindingState.currentTile.x + 1
    if eastX <= wState.maxX
        eastY = pathfindingState.currentTile.y
        east = get(wState.availableTiles, (eastX, eastY), nothing)
        if east === nothing
            return false
        end
        push!(neighbors, east)
    end

    southY = pathfindingState.currentTile.y - 1
    if southY >= 1
        southX = pathfindingState.currentTile.x
        south = get(wState.availableTiles, (southX, southY), nothing)
        if south === nothing
            return false
        end
        push!(neighbors, south)
    end

    westX = pathfindingState.currentTile.x - 1
    if westX >= 1
        westY = pathfindingState.currentTile.y
        west = get(wState.availableTiles, (westX, westY), nothing)
        if west === nothing
            return false
        end
        push!(neighbors, west)
    end


    if pathfindingState === wState.jobBState || pathfindingState === wState.jobAState
        wState.bench.initialPath_tilesExplored += 1
    end

    return true
end




function OPT1_CustomAStar(w::WorkerState, pathfindingState)::Union{Array{MapTile},Nothing}
    config = include("Config.jl")
    heuristicBooster = config.HEURISTIC_BOOSTER

    # Declaring this outside so it doesn't get re-allocated every iteration
    neighbors::Array{MapTile} = MapTile[]


    foundEnd = false

    while isempty(pathfindingState.frontier) == false || pathfindingState.postponed
        if pathfindingState.postponed == true
            pathfindingState.postponed = false
        else
            pathfindingState.currentTile::MapTile, _ = dequeue_pair!(pathfindingState.frontier)
        end

        if pathfindingState.currentTile === pathfindingState.endTile
            foundEnd = true
            break
        end
        @assert DEBUG_CoordinateOnlyCompare(pathfindingState.currentTile, pathfindingState.endTile) == false "Coordinates matched, ref didn't"

        neighborTilesExist = AStar_OPT1_GetNeighbors!(w, neighbors, pathfindingState)
        # This means "The Tile exists, but we haven't received it from the master core yet.
        if neighborTilesExist == false
            return nothing
        end

        for neighbor::MapTile in neighbors
            newCost = pathfindingState.costSoFar[pathfindingState.currentTile] + neighbor.costToReach

            if !haskey(pathfindingState.costSoFar, neighbor) || newCost < pathfindingState.costSoFar[neighbor]
                pathfindingState.costSoFar[neighbor] = newCost
                priority = newCost + heuristicBooster * _heuristic(neighbor, pathfindingState.endTile)
                pathfindingState.frontier[neighbor] = priority
                pathfindingState.cameFrom[neighbor] = pathfindingState.currentTile
            end
        end
    end

    @assert foundEnd == true "Didn't find end, but got to the ConstructPath part regardless. Worker had $(length(availableTiles)) tiles to work with"

    return ConstructPath(pathfindingState.endTile, pathfindingState.startTile, pathfindingState.cameFrom)
end












