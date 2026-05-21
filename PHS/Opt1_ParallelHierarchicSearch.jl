using MPI
# include("OPT1_WorkerEntry.jl")


# Before the following todos, complete the current OPT1 benchmarking.

#= TODO: Opt2

Destroy the dependency to previous workers in the beautification phase. Instead of beautifying with
the previous worker's last path, beautify with the start of the first local worker path, and the end of the 
last local worker path. This way, the number of paths to be solved locally can be turned into a variable

=#

#= TODO: Opt1 & Opt2

Have the master core passively send more mapdata to users, so that by the time that workers request for more,
there is probably already some map data available. Just need to do a quick iprobe after every work iteration, even if 
more data was not requested. On the master side, if there's no request coming in, send more data as soon as
any worker requests more. If the level increases, send everyone more data. This might be complicated to implement.

=#


#=
The first attempt at creating an optimized MPI Parallel Hierarchic Search (Opt1). What this one does:

# TODO: Implement the plan
The master core provides parts of the map to its workers. Each worker first receives the mapdata
that is expected to be necessary. If it is insufficient, the worker requests more.
Each worker solves two paths. If a worker needs to request more mapdata to solve one of its
paths, then instead of passively waiting for the new data to come in, it starts solving its other
path.

The A* pathfinding algorithm is modified to use a dictionary to find neighboring tiles, and to
save the state of the pathfinding process on that path, in case it needs to request more data
and come back later. I assume that the dictionary vs table lookup drawback produces a significant slowdown.
This can be tested later.

During the beautification stage, almost all the data should already be available from creating the initial
paths. Therefore, the switching between path A and path B in the initial stage won't be necessary, and thus 
the beautification step can involve one path for each core. Splitting the beautification paths into two
would reduce the effectiveness of the beautification.

Some notes:
I had to do a big refactor to make MapTile an immutable structs, as instances of mutable structs are
never isbits() compatible, which Isend() REQUIRES (regular send() does not)

This is definitely a major flaw of the Julia programming language / MPI interface. Mutable vs Immutable should
be something you decide as a programmer when the safety outweighs the inconvenience of locking yourself out of
modifying your own data. Without having looked into it, I assume this is just an unfortunate consequence 
of having a loose python-like "types don't exist" style language that's actually compiled. 
Might write about this in the thesis, might not. 

There is currently a small inefficiency, where sometimes the worker requests for more mapdata,
yet the master has already sent those maptiles for the worker's OTHER job. I'll be sure to measure the number
of times that an empty map supplement is delivered, to see if this is a truly a concern. The reason this happens
is because when the worker works on jobA, requests data, then works on jobB, misses data for jobB, it may not
know that perhaps the missing tiles from jobB were already on the way from the previous jobA supplement request.

# TODO Other optimizations
Currently, I have a few parts in the code that behave like blocking MPI sends and receives, but currently
they're handled via Isend and Irecv with blocking funcs following right after. This is because I had some
trouble getting these functions to work with my data, despite doing it with blocking funcs in the naive 
implementation, and having those same structs and arrays working just fine there. Anyway, I'm just trying 
to say that many of the Isend and Irecv's should be given another look

Similarly, the ordering in which things happen could be adjusted for better performance. For example,
the last worker currently solves the longest path in the beautification stage. The long path exists
due to beautification producing a number of paths that is not divisible by the number of workers. 
Should this task perhaps be delegated to the first worker, who is perhaps more likely to be done the
soonest? This should be benchmarked. 

In a similar vein, pathA is currenlty attempted to be solved before pathB, even though pathB
is more important than pathA, as pathB's are required for the next worker to start with beautification. This is, 
again, something that needs to be checked.



# TODO: Features
- GetEstimatedNecessaryCells probably still doesn't support waypointB being below waypointA. Go through it and see 
  if that's true


# TODO: Comprehensive logging of various things, benchmarks, etc. As for loggin
- The number of times that empty messages are sent
- How much mapdata is eventually sent to each worker compared to the full map data
- How often new mapdata is requested during the beautification phase, when no latency hiding exists to compensate
- How often pathA is solved before pathB, or vice versa
- Which worker usually solves its initial paths first

As for benchmarks
- Single threaded vs MPI accuracy
- Single threaded vs MPI time
- Scaling with cores on personal laptop vs DAS-5
- Beautification vs no beautification time
- Beautification vs no beautification accuracy
- How much time is spent passively waiting (i.e, when latency hiding fails)
- etc.

=#
# Sent by master core for the initial delivery of map data, before any jobs are posted.
const OPT1_MAP_INITIAL_DELIVERY = 0

# Sent by worker core when requesting more map data
const OPT1_MAP_REQUEST = 1

# Sent by the master core in response to a map request 
const OPT1_MAP_RESPONSE_DELIVERY = 2

# Sent by the master core to tell the worker which paths to create
const OPT1_INITIAL_JOB_REQUEST = 3

# Sent by the worker to the master, upon completing a path
const OPT1_PATH_DELIVERY_INITIAL_1 = 4
const OPT1_PATH_DELIVERY_INITIAL_2 = 5
const OPT1_PATH_DELIVERY_BEAUTIFIED = 6

const OPT1_BEAUTIFICATION_JOB_REQUEST = 7

const OPT1_WORKER_BENCHMARK_REQUEST = 8
const OPT1_WORKER_BENCHMARK_RESPONSE = 9


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



mutable struct OPT1_WorkerEntry
    workerRank::Int
    workerLevel_A::Int
    workerLevel_B::Int

    # Initial paths
    solvedPathA::Union{Array{MapTile,1},Nothing}
    solvedPathB::Union{Array{MapTile,1},Nothing}

    # array: for each "column", save the minY and maxY of the mapdata that was sent to the worker.
    sentMinMax::Array{Union{MinMaxY,Nothing}}

    # Beautification path
    solvedPathC::Union{Array{MapTile,1},Nothing}

    function OPT1_WorkerEntry(workerRank::Int, sentMinMax::Array{Union{MinMaxY,Nothing}})
        new(workerRank, 1, 1, nothing, nothing, sentMinMax, nothing)
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

    workerEntries::Array{OPT1_WorkerEntry}
    maxX::Int32
    maxY::Int32
    nranks
    currentLevel

    initialPaths::Vector{Tuple{MapTile,MapTile}}
    solved_initialPaths::Array{Array{MapTile,1},1}

    solved_beautyPaths::Array{Array{MapTile,1},1}

    initialWayPoints::Array{MapTile}
    beautifiedWayPoints::Array{MapTile}

    benchmarkData_Master::BenchmarkData_MasterCore
    iSendRequests
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
    benchmarkData_Worker::mBenchmarkData_WorkerCore

    # This holds iSend requests, so they aren't garbage collected until the full operation is done
    iSendRequests::Vector{MPI.Request}
end




# // ::: -------------------------:: Miscellanious Functions ::------------------------- ::: // 
#
#
#

function GetMiddleElementOfArray(theArray)
    return theArray[length(theArray)÷2]
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



function OPT1_AllBeautyPathsAreReceived(workerRecords::Array{OPT1_WorkerEntry})
    for record::OPT1_WorkerEntry in workerRecords
        if record.solvedPathC === nothing
            return false
        end
    end
    return true
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









function OPT1_Entry_BenchmarkingRunA(comm, nranks, rank, masterCore)
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

        # Discarding the result of the first run, due to warmup
        if i == 1
            continue
        end

        if rank == 0
            reportStruct::OPT1_BenchmarkingReportStruct = OPT1_Entry(comm, nranks, rank, masterCore, false)
            push!(reportStructs, reportStruct)
        else
            OPT1_Entry(comm, nranks, rank, masterCore, false)
        end
    end
    if rank == 0
        # TODO: Run the single threaded A*, put its info into the report struct too.

        println("The AVERAGE report:")
        averageReport = OPT1_AverageBenchmarkingReportStructs(reportStructs)
        println(OPT1_GenerateReportString(averageReport))

        fileName = OPT1_GenerateReportFilename(averageReport)

        path = joinpath("Benchmarks", "RunA")
        mkpath(path)

        filePath = joinpath(path, fileName)
        open(filePath, "w") do file
            serialize(file, averageReport)
        end
    end

end





# // ::: -------------------------:: MPI Functions ::------------------------- ::: // 
#
#
#
function OPT1_Entry(comm, nranks, rank, masterCore, handcraftedTestMap::Bool)
    config = include("Config.jl")
    if rank == masterCore
        seed::Int = CenAstar.InitializeSeed()
        mapName::String = ""
        if handcraftedTestMap == true
            # computedMaze::ComputedMaze = LoadMap("DebugMap_1")
            computedMaze::ComputedMaze = LoadMap("BigMap_1")
            # TODO: Proper custom map handling
            mapName = "CustomMap_TODONAMEPARSE"
        else
            width::Int32 = Int32(config.MAZE_SIZE_X)
            height::Int32 = Int32(config.MAZE_SIZE_Y)
            computedMaze = ComputeMaze(width, height)
            mapName = "RandomMap_Seed:$(seed)_Width:$(width)_Height:$(height)"
        end
    end

    MPI.Barrier(comm)

    if rank == masterCore
        reportStruct::OPT1_BenchmarkingReportStruct = OPT1_MasterCore(comm, nranks, rank, masterCore, computedMaze, mapName)
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



function OPT1_MasterCore(comm, nranks, rank, masterCore, computedMaze::ComputedMaze, mapName::String)
    T_startTime = time()
    T_startToBeautified::Float64 = @elapsed begin
        T_offlinePrelude::Float64 =
            @elapsed s::MasterState = OPT1_Master_HandleOfflinePrelude(comm, nranks, computedMaze, mapName)
        s.benchmarkData_Master.startTime = T_startTime
        s.benchmarkData_Master.secondsForOfflinePreludeBeforeSendingInitialJobs = T_offlinePrelude

        s.benchmarkData_Master.secondsToSendInitialPathsAndJobsToAllWorkers =
            @elapsed OPT1_Master_SendInitialJobs(s, s.initialPaths)

        while OPT1_AllBeautyPathsAreReceived(s.workerEntries) == false
            status = MPI.Probe(comm, MPI.Status; source=MPI.ANY_SOURCE, tag=MPI.ANY_TAG)
            source = MPI.Get_source(status)
            tag = MPI.Get_tag(status)
            # // ::: -------------------------:: Handling a Map supply request ::------------------------- ::: // 
            if tag == OPT1_MAP_REQUEST
                OPT1_Master_HandleMapRequest(s, status, source, tag)
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

        # // ::: -------------------------:: Processing the Results ::------------------------- ::: // 
        fullPath_Initial::Array{MapTile,1} = reduce(vcat, s.solved_initialPaths)
        fullPath_Initial = DeduplicateFinalPath(fullPath_Initial)
        fullPath_Beauty::Array{MapTile,1} = reduce(vcat, s.solved_beautyPaths)
        fullPath_Beauty = DeduplicateFinalPath(fullPath_Beauty)
    end # T_startToBeautified

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
        MPI.Probe(comm, MPI.Status, source=MPI.ANY_SOURCE, tag=OPT1_WORKER_BENCHMARK_RESPONSE)
        workerBenchmarkingBuffer_ref = Ref{BenchmarkData_WorkerCore}()

        MPI.Irecv!(workerBenchmarkingBuffer_ref, s.comm; source=MPI.ANY_SOURCE, tag=OPT1_WORKER_BENCHMARK_RESPONSE)
        workerBenchmarkingEntry::BenchmarkData_WorkerCore = workerBenchmarkingBuffer_ref[]
        push!(workerBenchmarkDatas, workerBenchmarkingEntry)
    end

    s.benchmarkData_Master.secondsFromStartToHavingReceivedAllBeautifiedPaths = T_startToBeautified
    s.benchmarkData_Master.finalLevel = s.currentLevel
    s.benchmarkData_Master.finalSize = s.horizontalExtensionSize * s.verticalEstimationSize

    # TODO: Move this out somewhere, so the same code isn't run 5 times
    stSeconds = @elapsed stSolution = st_AStar(s.computedMaze.startTile, s.computedMaze.endTile, s.computedMaze.allTiles)
    stCost = ComputePathCost(stSolution)

    reportStruct::OPT1_BenchmarkingReportStruct = OPT1_GenerateBenchmarkReport(s.benchmarkData_Master, workerBenchmarkDatas, stCost, stSeconds)

    return reportStruct
end














function OPT1_Master_HandleOfflinePrelude(comm, nranks, computedMaze::ComputedMaze, mapName::String)
    verticalEstimationSize_Default::Int32 = 64
    horizontalExtensionSize_Default::Int32 = 64
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
        OPT1_WorkerEntry[],
        maxX,
        maxY,
        nranks,
        currentLevel,
        initialPaths,
        Array{MapTile,1}[], # solved initial paths
        Array{MapTile,1}[], # solved beauty paths
        initialWayPoints,
        MapTile[], # beautified waypoints
        benchmarkData_Master,
        Vector{MPI.Request}())
    return s
end





function OPT1_Master_HandleMapRequest(s::MasterState, status::MPI.MPI_Status, source, tag)

    # TODO: Figure out this recv thing, which sould be a regular blocking one as the data is already there
    mapRequest_ref = Ref{OPT1_MapRequest}()
    mapRequest_MPIRequest = MPI.Irecv!(mapRequest_ref, s.comm; source=source, tag=OPT1_MAP_REQUEST)
    MPI.Wait(mapRequest_MPIRequest)
    mapRequest::OPT1_MapRequest = mapRequest_ref[]

    # levelBefore = s.currentLevel
    OPT1_UpdateRecord(s.workerEntries[source], mapRequest)
    s.currentLevel = OPT1_TryLevelUp(s.workerEntries)

    s.verticalEstimationSize = s.verticalEstimationSize_Default * (s.currentLevel^2)
    s.horizontalExtensionSize = s.horizontalExtensionSize_Default * (s.currentLevel^2)

    # if levelBefore != s.currentLevel
    #     println("The currentLevel after the map request was received is now $(s.currentLevel), and previously was $levelBefore")
    #     println("After level up, the vertical estimation size is $(s.verticalEstimationSize), and the horizontal extension size is $(s.horizontalExtensionSize)")
    # end

    sentMinMax::Array{Union{MinMaxY,Nothing}} = s.workerEntries[source].sentMinMax
    supplementMapTiles::Array{MapTile,1} =
        OPT1_GetEstimatedNecessaryCells(mapRequest.wayPointA, mapRequest.wayPointB, s.computedMaze.allTiles, s.verticalEstimationSize, s.horizontalExtensionSize, s.maxX, s.maxY, sentMinMax)

    req = MPI.Isend(supplementMapTiles, s.comm, dest=source, tag=OPT1_MAP_RESPONSE_DELIVERY)
    push!(s.iSendRequests, req)
    # println("Master Core sent a map supplement with $(length(supplementMapTiles)) tiles over to worker $source")
end






function OPT1_SendBeautificationJob(s::MasterState, worker)
    if worker > 1
        @assert OPT1_WorkerCompletedPathBOfInitialJob(s.workerEntries[worker-1]) "Previous worker was not done yet"
    end

    #=
    The beautifcation paths:
    For the first worker, it starts at the start of the own first path
    and ends at the middle of the own second path.

    For middle workers, it starts at the middle of the previous worker's second path,
    and ends at the middle of the own second path

    For the last worker, it starts at the middle of the previous worker's second path,
    and ends at the end of the own second path
    =#

    isOnlyWorker::Bool = worker == 1 && s.nranks == 2
    isFirstWorker::Bool = worker == 1
    isEndWorker::Bool = worker == s.nranks - 1
    isMiddleWorker::Bool = !isFirstWorker && !isEndWorker

    own::OPT1_WorkerEntry = s.workerEntries[worker]

    if isOnlyWorker
        beautyStartTile::MapTile = own.solvedPathA[end]
        beautyEndTile::MapTile = own.solvedPathB[1]

    elseif isFirstWorker
        beautyStartTile = own.solvedPathA[end]
        # @assert beautyStartTile.x == 1 && beautyStartTile.y == 1 "I believed that solved pathA had 1 1 at the end of the array, due to construction order. The first entry of the array though was $(own.solvedPathA[1])"
        beautyEndTile = GetMiddleElementOfArray(own.solvedPathB)

    elseif isMiddleWorker
        prev::OPT1_WorkerEntry = s.workerEntries[worker-1]
        beautyStartTile = GetMiddleElementOfArray(prev.solvedPathB)
        beautyEndTile = GetMiddleElementOfArray(own.solvedPathB)

    elseif isEndWorker
        prev = s.workerEntries[worker-1]
        beautyStartTile = GetMiddleElementOfArray(prev.solvedPathB)
        beautyEndTile = own.solvedPathB[1]
    else
        error("None were true, of isFirstWorker, isEndWorker, and isMiddleWorker")
    end

    beautificationJob::OPT1_Job = OPT1_Job(beautyStartTile, beautyEndTile)
    req = MPI.Isend(beautificationJob, s.comm; dest=worker, tag=OPT1_BEAUTIFICATION_JOB_REQUEST)
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
        s.workerEntries[source].solvedPathC = receivedPath
        push!(s.solved_beautyPaths, receivedPath)
        # // ::: -------------------------:: Early return here ::------------------------- ::: // 
        return
    else
        error("Received incompatible tag in HandleIncomingInitialSolvedPath: $tag")
    end
    push!(s.solved_initialPaths, receivedPath)

    firstPathReceived::Bool = s.workerEntries[source].solvedPathA !== nothing
    secondPathReceived::Bool = s.workerEntries[source].solvedPathB !== nothing
    bothPathsReceived::Bool = firstPathReceived && secondPathReceived
    hasNext::Bool = source + 1 <= (s.nranks - 1)

    # We only move ourselves to beautification if both initial paths are done
    if bothPathsReceived
        if source == 1
            OPT1_SendBeautificationJob(s, source)
        else
            previous = s.workerEntries[source-1]
            if OPT1_WorkerCompletedPathBOfInitialJob(previous)
                OPT1_SendBeautificationJob(s, source)
            end
        end
    end

    # We trigger the next worker to beautify if our second path is done, and we have a next worker
    if secondPathReceived && hasNext
        next::Int = source + 1
        nextEntry = s.workerEntries[next]
        nextIsWaiting = OPT1_WorkerCompletedInitialJob(nextEntry)
        if nextIsWaiting
            OPT1_SendBeautificationJob(s, next)
        end
    end

end







function OPT1_Master_SendInitialJobs(s::MasterState, paths::Vector{Tuple{MapTile,MapTile}})
    pathIndex = 1
    @assert length(paths) == 2 * (s.nranks - 1) "length of paths was $(length(paths)) and rhs was $(2*(s.nranks - 1))"
    for i in 1:s.nranks-1 # for each rank
        pathA = paths[pathIndex]

        sentMinMax::Array{Union{MinMaxY,Nothing}} = fill(nothing, s.maxX)

        pathA_estimatedNecessaryCells::Array{MapTile,1} =
            OPT1_GetEstimatedNecessaryCells(pathA[1], pathA[2], s.computedMaze.allTiles, s.verticalEstimationSize, s.horizontalExtensionSize, s.maxX, s.maxY, sentMinMax)
        pathIndex += 1

        pathB = paths[pathIndex]
        pathB_estimatedNecessaryCells::Array{MapTile,1} =
            OPT1_GetEstimatedNecessaryCells(pathB[1], pathB[2], s.computedMaze.allTiles, s.verticalEstimationSize, s.horizontalExtensionSize, s.maxX, s.maxY, sentMinMax)
        pathIndex += 1

        both_estimatedNecessaryCells::Array{MapTile,1} = unique(vcat(pathA_estimatedNecessaryCells, pathB_estimatedNecessaryCells))

        workerRank = i

        # mapDataForWorker::OPT1_PhsMapData = OPT1_PhsMapData(both_estimatedNecessaryCells)
        push!(s.iSendRequests, MPI.Isend(both_estimatedNecessaryCells, s.comm; dest=workerRank, tag=OPT1_MAP_INITIAL_DELIVERY))

        jobA::OPT1_Job = OPT1_Job(pathA[1], pathA[2])
        jobB::OPT1_Job = OPT1_Job(pathB[1], pathB[2])
        jobsForWorker::OPT1_JobRequest = OPT1_JobRequest(jobA, jobB, s.maxX, s.maxY)
        push!(s.iSendRequests, MPI.Isend(jobsForWorker, s.comm; dest=workerRank, tag=OPT1_INITIAL_JOB_REQUEST))


        push!(s.workerEntries, OPT1_WorkerEntry(workerRank, sentMinMax))
    end
end













function OPT1_WorkerCore(comm, nranks, rank, masterCore)
    T_startTime = time()
    w::WorkerState = OPT1_Worker_ReceiveInitialMapDataAndJobs(comm, rank)
    w.benchmarkData_Worker.startTime = T_startTime
    w.benchmarkData_Worker.timeOfReceivingInitialJob = time()

    OPT1_Worker_CompleteJobPair(w, OPT1_PATH_DELIVERY_INITIAL_1, OPT1_PATH_DELIVERY_INITIAL_2)
    w.benchmarkData_Worker.secondsFromReceivingJobToHavingSentInitialPaths = time() - w.benchmarkData_Worker.timeOfReceivingInitialJob


    T_beforeReceivingBeautificationJob = time()
    OPT1_Worker_ReceiveBeautificationJobs!(w)
    T_receivingBeautificationJob = time()
    OPT1_Worker_CompleteBeautyJob(w)
    w.benchmarkData_Worker.waitingForBeautificationJobAfterSolvingInitial = time() - T_beforeReceivingBeautificationJob
    w.benchmarkData_Worker.solvingBeautifiedPathAfterReceivingBeautificationJob = time() - T_receivingBeautificationJob
    w.benchmarkData_Worker.secondsFromReceivingJobToHavingSentBeautifiedPaths = time() - w.benchmarkData_Worker.timeOfReceivingInitialJob

    # Wait until we receive a benchmarking request from the master. We don't want to pollute MPI
    # when other workers are still busy.
    # benchmarkingRequestStatus = MPI.Probe(comm, MPI.Status, source=masterCore, tag=OPT1_WORKER_BENCHMARK_REQUEST)

    # benchmarkingRequestBuffer_ref = Ref{OPT1_WorkerBenchmarkingDataRequest}()
    benchmarkingRequestBuffer = Vector{Int64}
    benchmarkingRequestBuffer = MPI.recv(comm; source=masterCore, tag=OPT1_WORKER_BENCHMARK_REQUEST)

    mpiCompatibleBenchmark = mBenchmarkData_WorkerCore_MakeMPICompatbible(w.benchmarkData_Worker)
    MPI.Send(mpiCompatibleBenchmark, comm; dest=masterCore, tag=OPT1_WORKER_BENCHMARK_RESPONSE)

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



function OPT1_Worker_ReceiveAndProcessMapRequest!(w::WorkerState)
    comm = w.comm
    availableTiles = w.availableTiles
    rank = w.rank

    isMessageAvailable, mapSupplyStatus::MPI.Status = MPI.Iprobe(comm, MPI.Status, ; source=0, tag=OPT1_MAP_RESPONSE_DELIVERY)
    if isMessageAvailable == false
        T_waitingForDataToComeIn = time()
        w.benchmarkData_Worker.numberOfOccasionsMapDataWasNotAvailableAndIHadToWait += 1
        mapSupplyStatus = MPI.Probe(comm, MPI.Status, source=0, tag=OPT1_MAP_RESPONSE_DELIVERY)
        w.benchmarkData_Worker.secondsSpentWaitingForMapDataToComeIn += (time() - T_waitingForDataToComeIn)
    end

    incomingTilesSize = MPI.Get_count(mapSupplyStatus, MapTile)
    # println("Worker $rank has received a probe signal for a map supplement\n Supposedly, the mapdata will have $incomingTilesSize elements")

    mapSupplyDelivery = Array{MapTile,1}(undef, incomingTilesSize)

    incomingSupplyRequest = MPI.Irecv!(mapSupplyDelivery, comm; source=0, tag=OPT1_MAP_RESPONSE_DELIVERY)
    MPI.Wait(incomingSupplyRequest)

    # println("Worker $rank received a new batch of tiles, with $(length(mapSupplyDelivery)) tiles.")

    for suppliedTile::MapTile in mapSupplyDelivery
        @assert !haskey(availableTiles, (suppliedTile.x, suppliedTile.y)) "Worker $rank already had the tile $suppliedTile in its storage"
        # if haskey(availableTiles, (suppliedTile.x, suppliedTile.y))
        #     println("~~~~~~~~~~~++++++++++++~~~~~~~Worker $rank already had the tile $suppliedTile in its storage")
        # end
        # if haskey(availableTiles, (suppliedTile.x, suppliedTile.y)) == false
        availableTiles[(suppliedTile.x, suppliedTile.y)] = suppliedTile
        # end
    end
end





function OPT1_Worker_ReceiveBeautificationJobs!(w::WorkerState)
    beautyJob_Ref = Ref{OPT1_Job}()
    beautyJob_MPI_Request = MPI.Irecv!(beautyJob_Ref, w.comm; source=0, tag=OPT1_BEAUTIFICATION_JOB_REQUEST)
    MPI.Wait(beautyJob_MPI_Request)

    beautyJob::OPT1_Job = beautyJob_Ref[]

    startTuple = (beautyJob.wayPointA.x, beautyJob.wayPointA.y)
    endTuple = (beautyJob.wayPointB.x, beautyJob.wayPointB.y)

    while (!haskey(w.availableTiles, startTuple) || !haskey(w.availableTiles, endTuple))
        mapRequest::OPT1_MapRequest = OPT1_MapRequest(beautyJob.wayPointA, beautyJob.wayPointB, false, true)
        push!(w.iSendRequests, MPI.Isend(mapRequest, comm, dest=0, tag=OPT1_MAP_REQUEST))
        OPT1_Worker_ReceiveAndProcessMapRequest!(w)
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

    initialMapDataDelivery_MPIRequest = MPI.Irecv!(initialMapDataDelivery, comm; source=0, tag=OPT1_MAP_INITIAL_DELIVERY)
    MPI.Wait(initialMapDataDelivery_MPIRequest)


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

    workerBenchmarking = mBenchmarkData_WorkerCore(
        rank
    )
    w::WorkerState = WorkerState(comm, rank, availableTiles, maxX, maxY, jobAState, jobBState, nothing, workerBenchmarking, Vector{MPI.Request}())
    return w
end




function OPT1_Worker_CompleteBeautyJob(w::WorkerState)
    beautyJobSolved::Bool = false
    while beautyJobSolved == false
        T_beforeComputation = time()
        jobSolveResult = OPT1_CustomAStar(w.availableTiles, w.maxX, w.maxY, w.beautyJobState)
        w.benchmarkData_Worker.rawComputationSeconds_Beautify += time() - T_beforeComputation
        if jobSolveResult === nothing
            # Request for more data to come in, and wait for it
            w.benchmarkData_Worker.numberOfTimesNewMapDataWasRequested += 1
            OPT1_Worker_SendMapRequest(w.beautyJobState, false, w.comm, w; isBeauty=true)
            w.beautyJobState.postponed = true
            OPT1_Worker_ReceiveAndProcessMapRequest!(w)
        else
            beautyJobSolved = true
            OPT1_Worker_SendCompletedPath(jobSolveResult, OPT1_PATH_DELIVERY_BEAUTIFIED, w.comm, w)
        end
    end
end



function OPT1_Worker_CompleteJobPair(w::WorkerState, jobACompletionTag, jobBCompletionTag)
    jobASolved::Bool = false
    jobBSolved::Bool = false

    while !jobASolved || !jobBSolved

        if !jobASolved
            # Check if Job A's supplement has come in the mail yet.
            if w.jobAState.postponed
                OPT1_Worker_ReceiveAndProcessMapRequest!(w)
            end
            T_beforeComputation = time()
            jobA_solveResult = OPT1_CustomAStar(w.availableTiles, w.maxX, w.maxY, w.jobAState)
            w.benchmarkData_Worker.rawComputationSeconds_Initial += time() - T_beforeComputation
            if jobA_solveResult === nothing
                w.benchmarkData_Worker.numberOfTimesNewMapDataWasRequested += 1
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
                OPT1_Worker_ReceiveAndProcessMapRequest!(w)
            end
            T_beforeComputation = time()
            jobB_solveResult = OPT1_CustomAStar(w.availableTiles, w.maxX, w.maxY, w.jobBState)
            w.benchmarkData_Worker.rawComputationSeconds_Initial += time() - T_beforeComputation
            if jobB_solveResult === nothing
                w.benchmarkData_Worker.numberOfTimesNewMapDataWasRequested += 1
                OPT1_Worker_SendMapRequest(w.jobBState, false, w.comm, w)
                w.jobBState.postponed = true
            else
                jobBSolved = true
                OPT1_Worker_SendCompletedPath(jobB_solveResult, jobBCompletionTag, w.comm, w)
            end

        end

    end

end





















# // ::: -------------------------:: PATHFINDING ::------------------------- ::: // 
#
#
#
#
function OPT1_CustomAStar(availableTiles::Dict{Tuple{Int32,Int32},MapTile}, maxX::Int32, maxY::Int32, state::WorkerPathfindingState)::Union{Array{MapTile},Nothing}

    # Declaring this outside so it doesn't get re-allocated every iteration
    neighbors::Array{MapTile} = MapTile[]

    function AStar_OPT1_GetNeighbors!()::Bool
        # Returns nothing when a tile is missing, and the master core needs to supply it for us.



        empty!(neighbors)
        northY = state.currentTile.y + 1
        if northY <= maxY
            northX = state.currentTile.x
            north = get(availableTiles, (northX, northY), nothing)
            if north === nothing
                return false
            end
            push!(neighbors, north)
        end

        eastX = state.currentTile.x + 1
        if eastX <= maxX
            eastY = state.currentTile.y
            east = get(availableTiles, (eastX, eastY), nothing)
            if east === nothing
                return false
            end
            push!(neighbors, east)
        end

        southY = state.currentTile.y - 1
        if southY >= 1
            southX = state.currentTile.x
            south = get(availableTiles, (southX, southY), nothing)
            if south === nothing
                return false
            end
            push!(neighbors, south)
        end

        westX = state.currentTile.x - 1
        if westX >= 1
            westY = state.currentTile.y
            west = get(availableTiles, (westX, westY), nothing)
            if west === nothing
                return false
            end
            push!(neighbors, west)
        end

        return true
    end

    foundEnd = false

    while isempty(state.frontier) == false || state.postponed
        if state.postponed == true
            state.postponed = false
        else
            state.currentTile::MapTile, _ = dequeue_pair!(state.frontier)
        end

        if state.currentTile === state.endTile
            foundEnd = true
            break
        end
        @assert DEBUG_CoordinateOnlyCompare(state.currentTile, state.endTile) == false "Coordinates matched, ref didn't"

        neighborTilesExist = AStar_OPT1_GetNeighbors!()
        # This means "The Tile exists, but we haven't received it from the master core yet.
        if neighborTilesExist == false
            return nothing
        end

        for neighbor::MapTile in neighbors
            newCost = state.costSoFar[state.currentTile] + neighbor.costToReach

            if !haskey(state.costSoFar, neighbor) || newCost < state.costSoFar[neighbor]
                state.costSoFar[neighbor] = newCost
                priority = newCost + _heuristic(neighbor, state.endTile)
                state.frontier[neighbor] = priority
                state.cameFrom[neighbor] = state.currentTile
            end
        end
    end

    @assert foundEnd == true "Didn't find end, but got to the ConstructPath part regardless. Worker had $(length(availableTiles)) tiles to work with"

    return ConstructPath(state.endTile, state.startTile, state.cameFrom)
end












