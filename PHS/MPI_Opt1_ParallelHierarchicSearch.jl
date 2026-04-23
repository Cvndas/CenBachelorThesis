using MPI
# include("MPI_Opt1_WorkerEntry.jl")

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
const MPI_OPT1_MAP_INITIAL_DELIVERY = 0

# Sent by worker core when requesting more map data
const MPI_OPT1_MAP_REQUEST = 1

# Sent by the master core in response to a map request 
const MPI_OPT1_MAP_RESPONSE_DELIVERY = 2

# Sent by the master core to tell the worker which paths to create
const MPI_OPT1_INITIAL_JOB_REQUEST = 3

# Sent by the worker to the master, upon completing a path
const MPI_OPT1_PATH_DELIVERY_A = 4
const MPI_OPT1_PATH_DELIVERY_B = 5
const MPI_OPT1_PATH_DELIVERY_C = 6

const MPI_OPT1_BEAUTIFICATION_JOB_REQUEST = 7


# // ::: -------------------------:: Structs ::------------------------- ::: // 
#
#
#
struct MPI_Opt1_Job
    wayPointA::MapTile
    wayPointB::MapTile
end




struct MPI_Opt1_JobRequest
    jobA::MPI_Opt1_Job
    jobB::MPI_Opt1_Job
    # These are delivered alongside the job.
    maxX::Int32
    maxY::Int32
end



struct MPI_Opt1_MapRequest
    wayPointA::MapTile
    wayPointB::MapTile
    isWayPointA::Bool # used to "level up" how much material the master core will save
    levelUpBoth::Bool
end



mutable struct MinMaxY
    minY::Int32
    maxY::Int32
end

mutable struct MPI_Opt1_WorkerEntry
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

    function MPI_Opt1_WorkerEntry(workerRank::Int, sentMinMax::Array{Union{MinMaxY,Nothing}})
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

    workerEntries::Array{MPI_Opt1_WorkerEntry}
    maxX::Int32
    maxY::Int32
    nranks
    currentLevel

    initialPaths::Vector{Tuple{MapTile,MapTile}}
    solved_initialPaths::Array{Array{MapTile,1},1}

    solved_beautyPaths::Array{Array{MapTile,1},1}

    initialWayPoints::Array{MapTile}
    beautifiedWayPoints::Array{MapTile}
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
end




# // ::: -------------------------:: Miscellanious Functions ::------------------------- ::: // 
#
#
#

function GetMiddleElementOfArray(theArray)
    return theArray[length(theArray)÷2]
end


function MPI_OPT1_TryLevelUp(allEntries::Array{MPI_Opt1_WorkerEntry})
    maxLevel = -1
    for entry::MPI_Opt1_WorkerEntry in allEntries
        workerLevel = max(entry.workerLevel_A, entry.workerLevel_B)
        if workerLevel > maxLevel
            maxLevel = workerLevel
        end
    end

    return maxLevel
end


function MPI_OPT1_WorkerCompletedInitialJob(workerEntry::MPI_Opt1_WorkerEntry)
    return workerEntry.solvedPathA !== nothing && workerEntry.solvedPathB !== nothing
end

function MPI_OPT1_WorkerCompletedPathBOfInitialJob(workerEntry::MPI_Opt1_WorkerEntry)
    return workerEntry.solvedPathB !== nothing
end


function MPI_OPT1_UpdateRecord(record::MPI_Opt1_WorkerEntry, mapRequest::MPI_Opt1_MapRequest)
    if mapRequest.isWayPointA
        record.workerLevel_A += 1
    elseif mapRequest.levelUpBoth
        record.workerLevel_A += 1
        record.workerLevel_B += 1
    else
        record.workerLevel_B += 1
    end
end




function MPI_OPT1_AllInitialSolvedPathsAreReceived(workerRecords::Array{MPI_Opt1_WorkerEntry})
    for record::MPI_Opt1_WorkerEntry in workerRecords
        if record.solvedPathA === nothing || record.solvedPathB === nothing
            return false
        end
    end
    return true
end



function MPI_OPT1_AllBeautyPathsAreReceived(workerRecords::Array{MPI_Opt1_WorkerEntry})
    for record::MPI_Opt1_WorkerEntry in workerRecords
        if record.solvedPathC === nothing
            return false
        end
    end
    return true
end



# A function that took quite a few calories to write
function MPI_OPT1_GetEstimatedNecessaryCells(wayPointA::MapTile, wayPointB::MapTile, allTiles::Array{MapTile,2}, verticalEstimationSize::Int32, horizontalExtensionSize::Int32, maxX::Int32, maxY::Int32, sentMinMax::Array{Union{MinMaxY,Nothing}})::Array{MapTile,1}
    # TODO: Support this for when wayPointB is BELOW or to the LEFT of wayPointA. Will need some adjustments to the math
    println("~~~Going to get the estimated necessary cells for a path between $wayPointA and $wayPointB")
    # println("~~~Vertical estimation size: $verticalEstimationSize, horizontalExtensionSize: $horizontalExtensionSize")

    DEBUG_previouslySentNotAddedCount::Int = 0
    DEBUG_totalConsidered::Int = 0

    # // ::: -------------------------:: Creating the diagonals ::------------------------- ::: // 
    leftWayPoint::MapTile = if wayPointA.x < wayPointB.x
        wayPointA
    else
        wayPointB
    end

    wayPointXDif = abs(wayPointA.x - wayPointB.x)
    slope::Float64 = if wayPointA.y < wayPointB.y
        (wayPointB.y - wayPointA.y) / wayPointXDif
    else
        (wayPointA.y - wayPointB.y) / wayPointXDif
    end
    # println("~~~Computed a slope of $slope")

    diagonals = Tuple{Int32,Int32}[]

    leftMostX = min(wayPointA.x, wayPointB.x)
    leftMostX -= horizontalExtensionSize
    leftMostX = clamp(leftMostX, Int32(1), maxX)

    rightMostX = max(wayPointA.x, wayPointB.x)
    rightMostX += horizontalExtensionSize
    rightMostX = clamp(rightMostX, Int32(1), maxX)

    diagonalY::Float64 = Float64(leftWayPoint.y)
    for x in leftWayPoint.x:-1:leftMostX
        push!(diagonals, (x, round(Int32, diagonalY)))
        diagonalY -= slope
    end

    diagonalY = Float64(leftWayPoint.y) + slope
    for x in leftWayPoint.x+1:rightMostX
        push!(diagonals, (x, round(Int32, diagonalY)))
        diagonalY += slope
    end

    # println("~~~The diagonals: ")
    # display(diagonals)

    coordinates::Array{Tuple{Int32,Int32},1} = Tuple{Int32,Int32}[]

    # ::: -------------------------:: Grabbing columns from the diagonals ::------------------------- ::: // 
    for diagonal::Tuple{Int32,Int32} in diagonals

        lowest = diagonal[2] - verticalEstimationSize
        if lowest < 1
            lowest = 1
        end

        highest = diagonal[2] + verticalEstimationSize
        if highest > maxY
            highest = maxY
        end

        columnMinMax = sentMinMax[diagonal[1]]
        if columnMinMax === nothing
            for v in lowest:highest
                push!(coordinates, (diagonal[1], v))
            end
            newColumnMinMax::MinMaxY = MinMaxY(lowest, highest)
            sentMinMax[diagonal[1]] = newColumnMinMax

        else # If the sentMinMax did exist for this column, use that to selectively gather tiles to send
            for v in lowest:highest
                if v < columnMinMax.minY || v > columnMinMax.maxY
                    push!(coordinates, (diagonal[1], v))
                    DEBUG_totalConsidered += 1
                else
                    DEBUG_previouslySentNotAddedCount += 1
                    DEBUG_totalConsidered += 1
                end
            end
            if lowest < columnMinMax.minY
                columnMinMax.minY = lowest
            end
            if highest > columnMinMax.maxY
                columnMinMax.maxY = highest
            end
        end
    end
    # println("~~~The coordinates that were grabbed based on the diagonals:")
    # display(coordinates)

    mapTilePackage::Array{MapTile,1} = MapTile[]
    for coord in coordinates
        push!(mapTilePackage, allTiles[coord[1], coord[2]])
    end
    # println("~~~Created the mapTilePackage")
    println("~~~New Optimization: avoided sending $DEBUG_previouslySentNotAddedCount previously sent tiles. Instead, we sent $(length(mapTilePackage)) tiles, saving $(DEBUG_totalConsidered - length(mapTilePackage)) tiles")
    # TODO: Log the number of times that map supplements of length 0 are sent.
    # display(mapTilePackage)

    return mapTilePackage
end




#=
Idea: Take each point along the diagonal, and an arbitrary number of tiles above and below those diagonals.
Also extend this slightly to the left and the right.
=#
function OLD_MPI_OPT1_GetEstimatedNecessaryCells(wayPointA::MapTile, wayPointB::MapTile, allTiles::Array{MapTile,2}, verticalEstimationSize::Int32, horizontalExtension::Int32, maxX::Int32, maxY::Int32)::Array{MapTile,1}
    @assert wayPointA.x <= wayPointB.x && wayPointA.y <= wayPointB.y "WaypointB being below or to the left of wayPoint A is not yet supported"
    estimatedNecessaryCells = MapTile[]
    estimatedNecessaryCells_Coordinates = Tuple{Int32,Int32}[]
    diagonals = Tuple{Int32,Int32}[]

    leftMostX = min(wayPointA.x - horizontalExtension, wayPointB.x - horizontalExtension)
    if leftMostX < 1
        leftMostX = 1
    end

    rightMostX = max(wayPointA.x + horizontalExtension, wayPointB.x + horizontalExtension)
    if rightMostX > maxX
        rightMostX = maxX
    end

    xDifTotal = abs(wayPointA.x - wayPointB.x)
    yDifTotal = abs(wayPointA.y - wayPointB.y)

    yDifPerX::Float64 = Float64(yDifTotal) / Float64(xDifTotal)

    @assert yDifPerX > 0 "yDifPerX was <= 0, namely $yDifPerX, xDifTotal: $xDifTotal, yDifTotal: $yDifTotal"
    leftMostY = Int32(wayPointA.y - ((wayPointA.x - leftMostX) * yDifPerX))

    currentDiagonalY::Float64 = leftMostY - yDifPerX
    for x in leftMostX:rightMostX
        currentDiagonalY = currentDiagonalY + yDifPerX
        push!(diagonals, (x, Int32(currentDiagonalY)))
    end

    for diagonal::Tuple{Int32,Int32} in diagonals
        # The diagonal itself
        if diagonal[2] >= 1 && diagonal[2] <= maxY
            push!(estimatedNecessaryCells_Coordinates, diagonal)
        end
        # The tiles above and below the diagonal
        for i in 1:verticalEstimationSize
            bottomCoordY = diagonal[2] - i
            topCoordY = diagonal[2] + i
            if bottomCoordY >= 1
                push!(estimatedNecessaryCells_Coordinates, (diagonal[1], bottomCoordY))
            end
            if topCoordY <= maxY
                push!(estimatedNecessaryCells_Coordinates, (diagonal[1], topCoordY))
            end
        end
    end

    for cell in estimatedNecessaryCells_Coordinates
        push!(estimatedNecessaryCells, allTiles[cell[1], cell[2]])
    end

    return estimatedNecessaryCells
end













# // ::: -------------------------:: MPI Functions ::------------------------- ::: // 
#
#
#
function MPI_Opt1_Entry(comm, nranks, rank, host)
    if rank == 0
        println("Entered MPI_Opt1_PhsEntry")
        CenAstar.Initialize()
        computedMaze::ComputedMaze = ComputeMaze()
    end

    MPI.Barrier(comm)
    if rank == 0
        println("Master core generated the maze. Starting the PHS Procedure")
    end

    if rank == 0
        MPI_Opt1_MasterCore(comm, nranks, rank, host, computedMaze)
    else
        MPI_Opt1_WorkerCore(comm, nranks, rank, host)
    end

    MPI.Barrier(comm)
    if rank == 0
        println("All cores are done with the PHS Procedure.")
        println("Press enter to exit")
        readline()
        # fig = Figure()
        println("Done with main().")
    end
end



function MPI_Opt1_MasterCore(comm, nranks, rank, host, computedMaze::ComputedMaze)
    s::MasterState = MPI_OPT1_Master_HandleOfflinePrelude(comm, nranks, computedMaze)
    MPI_OPT1_Master_SendInitialJobs(s, s.initialPaths)


    # while MPI_OPT1_AllInitialSolvedPathsAreReceived(s.workerEntries) == false
    while MPI_OPT1_AllBeautyPathsAreReceived(s.workerEntries) == false
        status = MPI.Probe(comm, MPI.Status; source=MPI.ANY_SOURCE, tag=MPI.ANY_TAG)
        source = MPI.Get_source(status)
        tag = MPI.Get_tag(status)
        println("Master probed an incoming message from rank $source")
        # // ::: -------------------------:: Handling a Map supply request ::------------------------- ::: // 
        if tag == MPI_OPT1_MAP_REQUEST
            MPI_OPT1_Master_HandleMapRequest(s, status, source, tag)
            # ::: -------------------------:: HAndling an incoming path ::------------------------- ::: // 
        elseif tag == MPI_OPT1_PATH_DELIVERY_A || tag == MPI_OPT1_PATH_DELIVERY_B || tag == MPI_OPT1_PATH_DELIVERY_C
            MPI_OPT1_Master_HandleIncomingSolvedPath(s, status, source, tag)
        else
            error("Master received message with tag $tag, which was not expected")
        end
    end

    # // ::: -------------------------:: Processing the Results ::------------------------- ::: // 
    println("All worker paths are received")
    println("\n\n--- THE RESULTS ---\n")
    println("The results were reached with a final level of $(s.currentLevel)")
    fullPath_Initial::Array{MapTile,1} = reduce(vcat, s.solved_initialPaths)
    cost_Initial = ComputePathCost(fullPath_Initial)

    fullPath_Beauty::Array{MapTile,1} = reduce(vcat, s.solved_beautyPaths)
    cost_Beauty = ComputePathCost(fullPath_Beauty)

    println("Reconstructed the initial full path, which has cost $cost_Initial")
    println("Reconstructed the beautified full path, which has cost $cost_Beauty")
    # initialImg = CenAstar.ShowMaze(s.computedMaze.wallMapTiles, s.computedMaze.pathMapTiles, s.computedMaze.mapBorders, fullPath_Initial, MapTile[], wayPoints=s.initialWayPoints)
    beautyImg = CenAstar.ShowMaze(s.computedMaze.wallMapTiles, s.computedMaze.pathMapTiles, s.computedMaze.mapBorders, fullPath_Beauty, MapTile[], wayPoints=s.initialWayPoints)
    # // ::: -------------------------:: End of Processing the Results ::------------------------- ::: // 
end









function MPI_OPT1_Master_HandleOfflinePrelude(comm, nranks, computedMaze::ComputedMaze)
    verticalEstimationSize_Default::Int32 = 3
    horizontalExtensionSize_Default::Int32 = 3
    currentLevel = 1

    verticalEstimationSize::Int32 = verticalEstimationSize_Default
    horizontalExtensionSize::Int32 = horizontalExtensionSize_Default

    maxX::Int32 = Int32(size(computedMaze.allTiles, 1))
    maxY::Int32 = Int32(size(computedMaze.allTiles, 2))

    # Let's first generate some waypoints, as these determine what data the workers need
    initialWayPoints::Array{MapTile} = GenerateInitialWaypoints(computedMaze.startTile, computedMaze.endTile, (nranks - 1) * 2, computedMaze.allTiles)
    initialPaths::Vector{Tuple{MapTile,MapTile}} = Tuple{MapTile,MapTile}[]
    for i in 1:length(initialWayPoints)-1
        push!(initialPaths, (initialWayPoints[i], initialWayPoints[i+1]))
    end

    println("\nThe following initialPaths were created: \n+++ +++ +++ ")
    for path in initialPaths
        println("A: $(path[1]) to B: $(path[2])")
    end
    println("+++ +++ +++\n")

    s::MasterState = MasterState(
        comm,
        computedMaze,
        verticalEstimationSize,
        verticalEstimationSize_Default,
        horizontalExtensionSize,
        horizontalExtensionSize_Default,
        MPI_Opt1_WorkerEntry[],
        maxX,
        maxY,
        nranks,
        currentLevel,
        initialPaths,
        Array{MapTile,1}[], # solved initial paths
        Array{MapTile,1}[], # solved beauty paths
        initialWayPoints,
        MapTile[] # beautified waypoints
    )
    return s
end





function MPI_OPT1_Master_HandleMapRequest(s::MasterState, status::MPI.MPI_Status, source, tag)
    println("A map request from rank $source is incoming")

    # TODO: Figure out this recv thing, which sould be a regular blocking one as the data is already there
    mapRequest_ref = Ref{MPI_Opt1_MapRequest}()
    mapRequest_MPIRequest = MPI.Irecv!(mapRequest_ref, s.comm; source=source, tag=MPI_OPT1_MAP_REQUEST)
    MPI.Wait(mapRequest_MPIRequest)
    mapRequest::MPI_Opt1_MapRequest = mapRequest_ref[]
    println("Master read the map request from $source")

    levelBefore = s.currentLevel
    MPI_OPT1_UpdateRecord(s.workerEntries[source], mapRequest)
    s.currentLevel = MPI_OPT1_TryLevelUp(s.workerEntries)
    if levelBefore != s.currentLevel
        println("The currentLevel after the map request was received is now $(s.currentLevel), and previously was $levelBefore")
    end

    s.verticalEstimationSize = s.verticalEstimationSize_Default * s.currentLevel^2
    s.horizontalExtensionSize = s.horizontalExtensionSize_Default * s.currentLevel^2

    sentMinMax::Array{Union{MinMaxY,Nothing}} = s.workerEntries[source].sentMinMax
    supplementMapTiles::Array{MapTile,1} =
        MPI_OPT1_GetEstimatedNecessaryCells(mapRequest.wayPointA, mapRequest.wayPointB, s.computedMaze.allTiles, s.verticalEstimationSize, s.horizontalExtensionSize, s.maxX, s.maxY, sentMinMax)

    MPI.Isend(supplementMapTiles, s.comm, dest=source, tag=MPI_OPT1_MAP_RESPONSE_DELIVERY)
    println("Master Core sent a map supplement with $(length(supplementMapTiles)) tiles over to worker $source")
end


function MPI_OPT1_SendBeautificationJob(s::MasterState, worker)
    if worker > 1
        @assert MPI_OPT1_WorkerCompletedPathBOfInitialJob(s.workerEntries[worker-1]) "Previous worker was not done yet"
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

    own::MPI_Opt1_WorkerEntry = s.workerEntries[worker]

    if isOnlyWorker
        beautyStartTile::MapTile = own.solvedPathA[end]
        beautyEndTile::MapTile = own.solvedPathB[1]

    elseif isFirstWorker
        beautyStartTile = own.solvedPathA[end]
        @assert beautyStartTile.x == 1 && beautyStartTile.y == 1 "I believed that solved pathA had 1 1 at the end of the array, due to construction order. The first entry of the array though was $(own.solvedPathA[1])"
        beautyEndTile = GetMiddleElementOfArray(own.solvedPathB)

    elseif isMiddleWorker
        prev::MPI_Opt1_WorkerEntry = s.workerEntries[worker-1]
        beautyStartTile = GetMiddleElementOfArray(prev.solvedPathB)
        beautyEndTile = GetMiddleElementOfArray(own.solvedPathB)

    elseif isEndWorker
        prev = s.workerEntries[worker-1]
        beautyStartTile = GetMiddleElementOfArray(prev.solvedPathB)
        beautyEndTile = own.solvedPathB[1]
    else
        error("None were true, of isFirstWorker, isEndWorker, and isMiddleWorker")
    end

    beautificationJob::MPI_Opt1_Job = MPI_Opt1_Job(beautyStartTile, beautyEndTile)
    MPI.Isend(beautificationJob, s.comm; dest=worker, tag=MPI_OPT1_BEAUTIFICATION_JOB_REQUEST)
    println("Master core sent worker $worker his beautification job from $beautyStartTile to $beautyEndTile")
end



function MPI_OPT1_Master_HandleIncomingSolvedPath(s::MasterState, status::MPI.MPI_Status, source, tag)
    incomingPathSize = MPI.Get_count(status, MapTile)
    println("Master core is about to receive a path with count $incomingPathSize")
    receivedPath = Array{MapTile,1}(undef, incomingPathSize)
    incomingPath_MPIRequest = MPI.Irecv!(receivedPath, s.comm; source=source, tag=tag)
    MPI.Wait(incomingPath_MPIRequest)
    if tag == MPI_OPT1_PATH_DELIVERY_A
        println("Master core just received path A from worker $source")
        @assert s.workerEntries[source].solvedPathA === nothing "Core $source sent solved path A, but this was already solved"
        s.workerEntries[source].solvedPathA = receivedPath
    elseif tag == MPI_OPT1_PATH_DELIVERY_B
        println("Master core just received path B from worker $source")
        @assert s.workerEntries[source].solvedPathB === nothing "Core $source sent solved path B, but this was already solved"
        s.workerEntries[source].solvedPathB = receivedPath
    elseif tag == MPI_OPT1_PATH_DELIVERY_C
        println("### ### Master core received the beauty path from $source")
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
            MPI_OPT1_SendBeautificationJob(s, source)
        else
            previous = s.workerEntries[source-1]
            if MPI_OPT1_WorkerCompletedPathBOfInitialJob(previous)
                MPI_OPT1_SendBeautificationJob(s, source)
            end
        end
    end

    # We trigger the next worker to beautify if our second path is done, and we have a next worker
    if secondPathReceived && hasNext
        next::Int = source + 1
        nextEntry = s.workerEntries[next]
        nextIsWaiting = MPI_OPT1_WorkerCompletedInitialJob(nextEntry)
        if nextIsWaiting
            MPI_OPT1_SendBeautificationJob(s, next)
        end
    end

end





function MPI_OPT1_Master_SendInitialJobs(s::MasterState, paths::Vector{Tuple{MapTile,MapTile}})
    pendingSends::Vector{MPI.Request} = MPI.Request[]
    pathIndex = 1
    @assert length(paths) == 2 * (s.nranks - 1)
    for i in 1:s.nranks-1 # for each rank
        pathA = paths[pathIndex]

        sentMinMax::Array{Union{MinMaxY,Nothing}} = fill(nothing, s.maxX)

        pathA_estimatedNecessaryCells::Array{MapTile,1} =
            MPI_OPT1_GetEstimatedNecessaryCells(pathA[1], pathA[2], s.computedMaze.allTiles, s.verticalEstimationSize, s.horizontalExtensionSize, s.maxX, s.maxY, sentMinMax)
        pathIndex += 1

        pathB = paths[pathIndex]
        pathB_estimatedNecessaryCells::Array{MapTile,1} =
            MPI_OPT1_GetEstimatedNecessaryCells(pathB[1], pathB[2], s.computedMaze.allTiles, s.verticalEstimationSize, s.horizontalExtensionSize, s.maxX, s.maxY, sentMinMax)
        pathIndex += 1

        both_estimatedNecessaryCells::Array{MapTile,1} = unique(vcat(pathA_estimatedNecessaryCells, pathB_estimatedNecessaryCells))

        println("Created the necessary cells for paths $i and $(i+1) which has length $(length(both_estimatedNecessaryCells))")
        workerRank = i

        # mapDataForWorker::MPI_Opt1_PhsMapData = MPI_Opt1_PhsMapData(both_estimatedNecessaryCells)
        println("The map data for worker $workerRank has $(length(both_estimatedNecessaryCells)) elements")
        push!(pendingSends, MPI.Isend(both_estimatedNecessaryCells, s.comm; dest=workerRank, tag=MPI_OPT1_MAP_INITIAL_DELIVERY))

        jobA::MPI_Opt1_Job = MPI_Opt1_Job(pathA[1], pathA[2])
        jobB::MPI_Opt1_Job = MPI_Opt1_Job(pathB[1], pathB[2])
        jobsForWorker::MPI_Opt1_JobRequest = MPI_Opt1_JobRequest(jobA, jobB, s.maxX, s.maxY)
        push!(pendingSends, MPI.Isend(jobsForWorker, s.comm; dest=workerRank, tag=MPI_OPT1_INITIAL_JOB_REQUEST))


        push!(s.workerEntries, MPI_Opt1_WorkerEntry(workerRank, sentMinMax))
    end

    println("Sent off all the jobs and mapdata to the workers.")
end













function MPI_Opt1_WorkerCore(comm, nranks, rank, host)
    w::WorkerState = MPI_OPT1_Worker_ReceiveInitialMapDataAndJobs(comm, rank)

    MPI_OPT1_Worker_CompleteJobPair(w, MPI_OPT1_PATH_DELIVERY_A, MPI_OPT1_PATH_DELIVERY_B)

    println("Worker $(w.rank) is done with the initial job... Waiting for the beautification job...")

    MPI_OPT1_Worker_ReceiveBeautificationJobs!(w)
    MPI_OPT1_Worker_CompleteBeautyJob(w)

    println("::: ::: ::: Worker $(w.rank) should now be working on its beautification job")
end





function MPI_OPT1_Worker_SendMapRequest(jobState::WorkerPathfindingState, isWayPointA::Bool, comm; isBeauty=false)::MPI.Request
    mapRequest::MPI_Opt1_MapRequest = MPI_Opt1_MapRequest(jobState.startTile, jobState.endTile, isWayPointA, isBeauty)
    sendRequest::MPI.Request = MPI.Isend(mapRequest, comm, dest=0, tag=MPI_OPT1_MAP_REQUEST)
    return sendRequest
end


function MPI_OPT1_Worker_SendCompletedPath(solvedPath::Array{MapTile}, TAG_TO_USE, comm)
    MPI.Isend(solvedPath, comm, dest=0, tag=TAG_TO_USE)
end




function MPI_OPT1_Worker_ReceiveAndProcessMapRequest!(availableTiles::Dict{Tuple{Int32,Int32},MapTile}, comm, rank)

    mapSupplyStatus = MPI.Probe(comm, MPI.Status, source=0, tag=MPI_OPT1_MAP_RESPONSE_DELIVERY)
    incomingTilesSize = MPI.Get_count(mapSupplyStatus, MapTile)
    println("Worker $rank has received a probe signal for a map supplement\n Supposedly, the mapdata will have $incomingTilesSize elements")

    mapSupplyDelivery = Array{MapTile,1}(undef, incomingTilesSize)

    # I don't know why I can't get this to work with MPI.recv() now. Sad.
    # Since the probe was blocking, this recv can be blocking too. We already know the data is ready 
    incomingSupplyRequest = MPI.Irecv!(mapSupplyDelivery, comm; source=0, tag=MPI_OPT1_MAP_RESPONSE_DELIVERY)
    MPI.Wait(incomingSupplyRequest)

    println("Worker $rank received a new batch of tiles, with $(length(mapSupplyDelivery)) tiles.")

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




function MPI_OPT1_Worker_ReceiveBeautificationJobs!(w::WorkerState)
    beautyJob_Ref = Ref{MPI_Opt1_Job}()
    beautyJob_MPI_Request = MPI.Irecv!(beautyJob_Ref, w.comm; source=0, tag=MPI_OPT1_BEAUTIFICATION_JOB_REQUEST)
    MPI.Wait(beautyJob_MPI_Request)

    beautyJob::MPI_Opt1_Job = beautyJob_Ref[]

    startTuple = (beautyJob.wayPointA.x, beautyJob.wayPointA.y)
    endTuple = (beautyJob.wayPointB.x, beautyJob.wayPointB.y)

    # TODO: This code is not tested yet
    while (!haskey(w.availableTiles, startTuple) || !haskey(w.availableTiles, endTuple))
        println("Worker $(w.rank) did not have the start or end tuples of the beautification job it just received.")
        mapRequest::MPI_Opt1_MapRequest = MPI_Opt1_MapRequest(beautyJob.wayPointA, beautyJob.wayPointB, false, true)
        sendRequest::MPI.Request = MPI.Isend(mapRequest, comm, dest=0, tag=MPI_OPT1_MAP_REQUEST)
        MPI_OPT1_Worker_ReceiveAndProcessMapRequest!(w.availableTiles, w.comm, w.rank)
    end

    beauty_startTile = w.availableTiles[startTuple]
    beauty_endTile = w.availableTiles[endTuple]

    w.beautyJobState = WorkerPathfindingState(beauty_startTile, beauty_endTile)
    println("Worker $(w.rank) received a beauty job with startTile $(beautyJob.wayPointA) and endTile $(beautyJob.wayPointB)")
end




function MPI_OPT1_Worker_ReceiveInitialMapDataAndJobs(comm, rank)::WorkerState
    # # The first thing we expect is the initial path delivery
    # The map data is sent first, but we can open up the mailbos for the job request in the meantime
    initialJobRequest_Ref = Ref{MPI_Opt1_JobRequest}()
    initialJobRequest_MPIRequest = MPI.Irecv!(initialJobRequest_Ref, comm; source=0, tag=MPI_OPT1_INITIAL_JOB_REQUEST)

    initialMapDataDelivery_Status = MPI.Probe(comm, MPI.Status, source=0, tag=MPI_OPT1_MAP_INITIAL_DELIVERY)
    mapDataCount = MPI.Get_count(initialMapDataDelivery_Status, MapTile)
    println("Worker $rank has received a probe signal for the initial map delivery\nThe mapdata will have $mapDataCount elements")

    initialMapDataDelivery = Array{MapTile,1}(undef, mapDataCount)

    initialMapDataDelivery_MPIRequest = MPI.Irecv!(initialMapDataDelivery, comm; source=0, tag=MPI_OPT1_MAP_INITIAL_DELIVERY)
    MPI.Wait(initialMapDataDelivery_MPIRequest)

    println("Worker $rank received the initial map data delivery, which has $(length(initialMapDataDelivery)) map tiles")

    # This is probably very slow.
    availableTiles::Dict{Tuple{Int32,Int32},MapTile} = Dict{Tuple{Int32,Int32},MapTile}()
    for tile::MapTile in initialMapDataDelivery
        availableTiles[(tile.x, tile.y)] = tile
    end

    MPI.Wait(initialJobRequest_MPIRequest)
    initialJobRequest::MPI_Opt1_JobRequest = initialJobRequest_Ref[]
    jobA::MPI_Opt1_Job = initialJobRequest.jobA
    jobB::MPI_Opt1_Job = initialJobRequest.jobB

    maxX::Int32 = initialJobRequest.maxX
    maxY::Int32 = initialJobRequest.maxY

    jobA_startTile = availableTiles[(jobA.wayPointA.x, jobA.wayPointA.y)]
    jobA_endTile = availableTiles[(jobA.wayPointB.x, jobA.wayPointB.y)]

    jobB_startTile = availableTiles[(jobB.wayPointA.x, jobB.wayPointA.y)]
    jobB_endTile = availableTiles[(jobB.wayPointB.x, jobB.wayPointB.y)]

    jobAState::WorkerPathfindingState = WorkerPathfindingState(jobA_startTile, jobA_endTile)
    jobBState::WorkerPathfindingState = WorkerPathfindingState(jobB_startTile, jobB_endTile)

    w::WorkerState = WorkerState(comm, rank, availableTiles, maxX, maxY, jobAState, jobBState, nothing)
    return w
end




function MPI_OPT1_Worker_CompleteBeautyJob(w::WorkerState)
    beautyJobSolved::Bool = false
    while beautyJobSolved == false
        jobSolveResult = MPI_OPT1_CustomAStar(w.availableTiles, w.maxX, w.maxY, w.beautyJobState)
        if jobSolveResult === nothing
            # Request for more data to come in, and wait for it
            println("### ### ###: Worker $(w.rank) has requested more tiles during the beautification process!!! Avoid this, as there is no latency hiding in this phase")
            sendReq = MPI_OPT1_Worker_SendMapRequest(w.beautyJobState, false, w.comm; isBeauty=true)
            w.beautyJobState.postponed = true
            MPI_OPT1_Worker_ReceiveAndProcessMapRequest!(w.availableTiles, w.comm, w.rank)
            println("Worker $(w.rank) received its map supplement during the beauty stage")
        else
            beautyJobSolved = true
            println("### ### ### Worker $(w.rank) completed his beauty job!")
            MPI_OPT1_Worker_SendCompletedPath(jobSolveResult, MPI_OPT1_PATH_DELIVERY_C, w.comm)
            println("### ### ### Worker $(w.rank) has sent his completed beauty path to the master core")
        end

    end
end



function MPI_OPT1_Worker_CompleteJobPair(w::WorkerState, jobACompletionTag, jobBCompletionTag)
    jobASolved::Bool = false
    jobBSolved::Bool = false

    println("Worker $(w.rank) will solve paths ($(w.jobAState.startTile), $(w.jobAState.endTile)) and  ($(w.jobBState.startTile), $(w.jobBState.endTile))")
    while !jobASolved || !jobBSolved
        jobA_solveResult = MPI_OPT1_CustomAStar(w.availableTiles, w.maxX, w.maxY, w.jobAState)
        if jobA_solveResult === nothing

            println("Worker $(w.rank) needs more data to solve its local path for job A.")
            sendReq = MPI_OPT1_Worker_SendMapRequest(w.jobAState, true, w.comm)
            w.jobAState.postponed = true
        else
            println("worker $(w.rank) created a local path of length $(length(jobA_solveResult))")
            jobASolved = true
            MPI_OPT1_Worker_SendCompletedPath(jobA_solveResult, jobACompletionTag, w.comm)
            println("Worker $(w.rank) sent back a path that starts at $(jobA_solveResult[end]) and ends at $(jobA_solveResult[1])")
        end

        # Check if Job B's supplement has come in the mail yet 
        if w.jobBState.postponed
            MPI_OPT1_Worker_ReceiveAndProcessMapRequest!(w.availableTiles, w.comm, w.rank)
            println("Worker $(w.rank) has received its JobB map supplement")
        end

        jobB_solveResult = MPI_OPT1_CustomAStar(w.availableTiles, w.maxX, w.maxY, w.jobBState)
        if jobB_solveResult === nothing
            println("Worker $(w.rank) needs more data to solve its local path for job B.")
            sendReq = MPI_OPT1_Worker_SendMapRequest(w.jobBState, false, w.comm)
            w.jobBState.postponed = true
        else
            println("worker $(w.rank) created a local path of length $(length(jobB_solveResult))")
            jobBSolved = true
            MPI_OPT1_Worker_SendCompletedPath(jobB_solveResult, jobBCompletionTag, w.comm)
            println("Worker $(w.rank) sent back a path that starts at $(jobB_solveResult[end]) and ends at $(jobB_solveResult[1])")
        end

        # Check if Job A's supplement has come in the mail yet.
        if w.jobAState.postponed
            MPI_OPT1_Worker_ReceiveAndProcessMapRequest!(w.availableTiles, w.comm, w.rank)
            println("Worker $(w.rank) has received its JobA map supplement")
        end
    end

end





















# // ::: -------------------------:: PATHFINDING ::------------------------- ::: // 
#
#
#
#
function MPI_OPT1_CustomAStar(availableTiles::Dict{Tuple{Int32,Int32},MapTile}, maxX::Int32, maxY::Int32, state::WorkerPathfindingState)::Union{Array{MapTile},Nothing}

    # Declaring this outside so it doesn't get re-allocated every iteration
    neighbors::Array{MapTile} = MapTile[]

    function AStar_MPI_Opt1_GetNeighbors!()::Bool
        # Returns nothing when a tile is missing, and the master core needs to supply it for us.



        empty!(neighbors)
        northY = state.currentTile.y + 1
        if northY <= maxY
            northX = state.currentTile.x
            north = get(availableTiles, (northX, northY), nothing)
            if north === nothing
                # println("Failed to find the northtile with ($northX, $northY)")
                return false
            end
            push!(neighbors, north)
        end

        eastX = state.currentTile.x + 1
        if eastX <= maxX
            eastY = state.currentTile.y
            east = get(availableTiles, (eastX, eastY), nothing)
            if east === nothing
                # println("Failed to find the easttile with ($eastX, $eastY)")
                return false
            end
            push!(neighbors, east)
        end

        southY = state.currentTile.y - 1
        if southY >= 1
            southX = state.currentTile.x
            south = get(availableTiles, (southX, southY), nothing)
            if south === nothing
                # println("Failed to find the southtile with ($southX, $southY)")
                return false
            end
            push!(neighbors, south)
        end

        westX = state.currentTile.x - 1
        if westX >= 1
            westY = state.currentTile.y
            west = get(availableTiles, (westX, westY), nothing)
            if west === nothing
                # println("Failed to find the westtile with ($westX, $westY)")
                return false
            end
            push!(neighbors, west)
        end

        return true
    end

    foundEnd = false

    while isempty(state.frontier) == false
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

        neighborTilesExist = AStar_MPI_Opt1_GetNeighbors!()
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

    @assert foundEnd == true "Didn't find end, but got to the ConstructPath part regardless"

    return ConstructPath(state.endTile, state.startTile, state.cameFrom)
end












