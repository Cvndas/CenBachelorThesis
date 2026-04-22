using MPI

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
and come back later.

Some notes:
I had to do a big refactor to make MapTile an immutable structs, as instances of mutable structs are
never isbits() compatible, which Isend() REQUIRES (regular send() does not)

This is definitely a major flaw of the Julia programming language / MPI interface. Mutable vs Immutable should
be something you decide as a programmer when the safety outweighs the inconvenience of locking yourself out of
modifying your own data. Might write about this in the thesis. 

=#
# Sent by master core for the initial delivery of map data, before any jobs are posted.
const MPI_OPT1_MAP_INITIAL_DELIVERY = 0

# Sent by worker core when requesting more map data
const MPI_OPT1_MAP_REQUEST = 1

# Sent by the master core in response to a map request 
const MPI_OPT1_MAP_RESPONSE_DELIVERY = 2

# Sent by the master core to tell the worker which paths to create
const MPI_OPT1_JOB_REQUEST = 3

# Sent by the worker to the master, upon completing a path
const MPI_OPT1_PATH_DELIVERY_A = 4
const MPI_OPT1_PATH_DELIVERY_B = 5


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
end





mutable struct MPI_Opt1_WorkerEntry
    workerRank::Int
    workerLevel_A::Int
    workerLevel_B::Int
    pathAReceived::Bool
    pathBReceived::Bool
    function MPI_Opt1_WorkerEntry(workerRank::Int)
        new(workerRank, 1, 1, false, false)
    end
end


function TryLevelUp(allEntries::Array{MPI_Opt1_WorkerEntry})
    maxLevel = -1
    for entry::MPI_Opt1_WorkerEntry in allEntries
        workerLevel = max(entry.workerLevel_A, entry.workerLevel_B)
        if workerLevel > maxLevel
            maxLevel = workerLevel
        end
    end

    return maxLevel
end

function UpdateRecord(record::MPI_Opt1_WorkerEntry, mapRequest::MPI_Opt1_MapRequest)
    if mapRequest.isWayPointA
        record.workerLevel_A += 1
    else
        record.workerLevel_B += 1
    end
end



function MPI_Opt1_PhsEntry(comm, nranks, rank, host)
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
        MPI_Opt1_PhsMasterCore(comm, nranks, rank, host, computedMaze)
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





function AllPathsAreReceived(workerRecords::Array{MPI_Opt1_WorkerEntry})
    for record::MPI_Opt1_WorkerEntry in workerRecords
        if record.pathAReceived == false || record.pathBReceived == false
            return false
        end
    end
    return true
end





function MPI_Opt1_PhsMasterCore(comm, nranks, rank, host, computedMaze::ComputedMaze)
    # TODO: Increase the number when it's all tested to work.
    verticalEstimationSize_Default::Int32 = 3
    horizontalExtensionSize_Default::Int32 = 3
    currentLevel = 1

    verticalEstimationSize::Int32 = verticalEstimationSize_Default
    horizontalExtensionSize::Int32 = horizontalExtensionSize_Default

    maxX::Int32 = Int32(size(computedMaze.allTiles, 1))
    maxY::Int32 = Int32(size(computedMaze.allTiles, 2))

    # Let's first generate some waypoints, as these determine what data the workers need
    wayPoints::Array{MapTile} = GenerateInitialWaypoints(computedMaze.startTile, computedMaze.endTile, (nranks - 1) * 2, computedMaze.allTiles)
    paths::Vector{Tuple{MapTile,MapTile}} = Tuple{MapTile,MapTile}[]
    for i in 1:length(wayPoints)-1
        push!(paths, (wayPoints[i], wayPoints[i+1]))
    end

    println("The following paths were created")
    for path in paths
        println("A: $(path[1]) to B: $(path[2])")
    end

    # ::: -------------------------:: Sending the initial jobs to the workers ::------------------------- ::: // 
    pendingSends::Vector{MPI.Request} = MPI.Request[]
    for i in 1:length(paths)÷2 # each worker gets two paths.
        @assert i <= nranks - 1 "nranks -1: $(nranks-1), i: $i"
        pathA = paths[i]
        pathA_estimatedNecessaryCells::Array{MapTile,1} =
            GetEstimatedNecessaryCells(pathA[1], pathA[2], computedMaze.allTiles, verticalEstimationSize, horizontalExtensionSize, maxX, maxY)

        pathB = paths[i+1]
        pathB_estimatedNecessaryCells::Array{MapTile,1} =
            GetEstimatedNecessaryCells(pathB[1], pathB[2], computedMaze.allTiles, verticalEstimationSize, horizontalExtensionSize, maxX, maxY)

        both_estimatedNecessaryCells::Array{MapTile,1} = unique(vcat(pathA_estimatedNecessaryCells, pathB_estimatedNecessaryCells))

        println("Created the necessary cells for paths $i and $(i+1) which has length $(length(both_estimatedNecessaryCells))")
        # if i == 1
        #     println("The estimated necessary cells of the first path: $(values(pathA_estimatedNecessaryCells))")
        # end

        workerRank = i

        # mapDataForWorker::MPI_Opt1_PhsMapData = MPI_Opt1_PhsMapData(both_estimatedNecessaryCells)
        println("The map data for worker $workerRank has $(length(both_estimatedNecessaryCells)) elements")
        push!(pendingSends, MPI.Isend(both_estimatedNecessaryCells, comm; dest=workerRank, tag=MPI_OPT1_MAP_INITIAL_DELIVERY))

        jobA::MPI_Opt1_Job = MPI_Opt1_Job(pathA[1], pathB[2])
        jobB::MPI_Opt1_Job = MPI_Opt1_Job(pathB[1], pathB[2])
        jobsForWorker::MPI_Opt1_JobRequest = MPI_Opt1_JobRequest(jobA, jobB, maxX, maxY)
        push!(pendingSends, MPI.Isend(jobsForWorker, comm; dest=workerRank, tag=MPI_OPT1_JOB_REQUEST))
    end

    println("Sent off all the jobs and mapdata to the workers.")
    for pendingSend::MPI.Request in pendingSends
        status = MPI.Wait(pendingSend, MPI.Status)
        # println("One of the pending sends has been completed::: source: $(status.MPI_SOURCE), tag: $(status.MPI_TAG)")
    end

    # ::: -------------------------:: All workers should be busy now ::------------------------- ::: // 
    # Let's create the registry
    workerRecords::Array{MPI_Opt1_WorkerEntry} = MPI_Opt1_WorkerEntry[]
    for workerRank in 1:nranks-1
        push!(workerRecords, MPI_Opt1_WorkerEntry(workerRank))
    end

    initialPaths::Array{Array{MapTile,1},1} = Array{MapTile,1}[]

    while AllPathsAreReceived(workerRecords) == false
        status = MPI.Probe(comm, MPI.Status; source=MPI.ANY_SOURCE, tag=MPI.ANY_TAG)
        source = MPI.Get_source(status)
        tag = MPI.Get_tag(status)
        println("Master probed an incoming message from rank $source")

        # // ::: -------------------------:: Handling a Map supply request ::------------------------- ::: // 
        if tag == MPI_OPT1_MAP_REQUEST
            println("A map request from rank $source is incoming")

            # TODO: This is a crash.
            # TODO: Figure out this recv thing, which sould be a regular blocking one as the data is already there
            mapRequest_ref = Ref{MPI_Opt1_MapRequest}()
            mapRequest_MPIRequest = MPI.Irecv!(mapRequest_ref, comm; source=source, tag=MPI_OPT1_MAP_REQUEST)
            MPI.Wait(mapRequest_MPIRequest)
            mapRequest::MPI_Opt1_MapRequest = mapRequest_ref[]
            println("Master read the map request from $source")

            levelBefore = currentLevel
            UpdateRecord(workerRecords[source], mapRequest)
            currentLevel = TryLevelUp(workerRecords)
            if levelBefore != currentLevel
                println("The currentLevel after the map request was received is now $currentLevel, and previously was $levelBefore")
            end

            verticalEstimationSize = verticalEstimationSize_Default * currentLevel
            horizontalExtensionSize = horizontalExtensionSize_Default * currentLevel

            supplementMapTiles::Array{MapTile,1} =
                GetEstimatedNecessaryCells(mapRequest.wayPointA, mapRequest.wayPointB, computedMaze.allTiles, verticalEstimationSize, horizontalExtensionSize, maxX, maxY)

            push!(pendingSends, MPI.Isend(supplementMapTiles, comm, dest=source, tag=MPI_OPT1_MAP_RESPONSE_DELIVERY))
            println("Master Core sent a map supplement with $(length(supplementMapTiles)) tiles over to worker $source")

            # ::: -------------------------:: HAndling an incoming path ::------------------------- ::: // 
        elseif tag == MPI_OPT1_PATH_DELIVERY_A || tag == MPI_OPT1_PATH_DELIVERY_B
            incomingPathSize = MPI.Get_count(status, MapTile)
            println("Master core is about to receive a path with count $incomingPathSize")
            receivedPath = Array{MapTile,1}(undef, incomingPathSize)
            incomingPath_MPIRequest = MPI.Irecv!(receivedPath, comm; source=source, tag=tag)
            MPI.Wait(incomingPath_MPIRequest)
            if tag == MPI_OPT1_PATH_DELIVERY_A
                println("Master core just received path A from worker $source")
                workerRecords[source].pathAReceived = true
            else
                println("Master core just received path B from worker $source")
                workerRecords[source].pathBReceived = true
            end
            push!(initialPaths, receivedPath)
        else
            error("Master received message with tag $tag, which was not expected")
        end
    end

    println("All worker paths are received")

    println("\n--- THE RESULTS ---\n")
    fullPath_Initial::Array{MapTile,1} = reduce(vcat, initialPaths)
    cost_Initial = ComputePathCost(fullPath_Initial)
    println("Reconstructed the initial full path, which has cost $cost_Initial")
    _ = CenAstar.ShowMaze(computedMaze.wallMapTiles, computedMaze.pathMapTiles, computedMaze.mapBorders, fullPath_Initial, MapTile[])

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

function SendCompletedPath(solvedPath::Array{MapTile}, pathId, comm)
    # // ::: -------------------------:: Setting the tag ::------------------------- ::: // 
    if pathId == :pathA
        tag = MPI_OPT1_PATH_DELIVERY_A
    else
        @assert pathId == :pathB
        tag = MPI_OPT1_PATH_DELIVERY_B
    end

    MPI.Isend(solvedPath, comm, dest=0, tag=tag)
end


function MPI_Opt1_WorkerCore(comm, nranks, rank, host)
    # # The first thing we expect is the initial path delivery
    # The map data is sent first, but we can open up the mailbos for the job request in the meantime
    initialJobRequest_Ref = Ref{MPI_Opt1_JobRequest}()
    initialJobRequest_MPIRequest = MPI.Irecv!(initialJobRequest_Ref, comm; source=0, tag=MPI_OPT1_JOB_REQUEST)

    initialMapDataDelivery_Status = MPI.Probe(comm, MPI.Status, source=0, tag=MPI_OPT1_MAP_INITIAL_DELIVERY)
    mapDataCount = MPI.Get_count(initialMapDataDelivery_Status, MapTile)
    println("Worker $rank has received a probe signal for the initial map delivery\nSupposedly, the mapdata would have $mapDataCount elements")

    initialMapDataDelivery = Array{MapTile,1}(undef, mapDataCount)

    # I don't know why I can't get this to work with MPI.recv() now. Sad.
    # Since the probe was blocking, this recv can be blocking too. We already know the data is ready 
    initialMapDataDelivery_MPIRequest = MPI.Irecv!(initialMapDataDelivery, comm; source=0, tag=MPI_OPT1_MAP_INITIAL_DELIVERY)
    MPI.Wait(initialMapDataDelivery_MPIRequest)

    println("Worker $rank received the initial map data delivery, which has $(length(initialMapDataDelivery)) map tiles")
    if rank == 1
        println("Some samples")
        for i in 1:5
            println(initialMapDataDelivery[i])
        end
    end

    #  ::: -------------------------:: Loading the available tiles into the local dict. ::------------------------- ::: // 
    # probably very slow.

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

    # println("Worker $rank received the initial job request, which has map tiles $(jobA.wayPointA) and $(jobA.wayPointB) for job A, and map tiles $(jobB.wayPointA) and $(jobB.wayPointB) for job B")
    #=
    The main job: We're going to try to solve both jobA and jobB. If we don't have the tiles necessary for 
    solving one, we send a request for more data, and switch to the other.
    =#

    jobA_startTile = availableTiles[(jobA.wayPointA.x, jobA.wayPointA.y)]
    jobA_endTile = availableTiles[(jobA.wayPointB.x, jobA.wayPointB.y)]

    jobB_startTile = availableTiles[(jobB.wayPointA.x, jobB.wayPointA.y)]
    jobB_endTile = availableTiles[(jobB.wayPointB.x, jobB.wayPointB.y)]

    jobAState::WorkerPathfindingState = WorkerPathfindingState(jobA_startTile, jobA_endTile)
    jobBState::WorkerPathfindingState = WorkerPathfindingState(jobB_startTile, jobB_endTile)

    jobASolved = false
    jobBSolved = false
    while !jobASolved || !jobBSolved
        jobA_solveResult = AStar_MPI_Opt1(availableTiles, maxX, maxY, jobAState)
        if jobA_solveResult === nothing
            # TODO
            println("Worker $rank needs more data to solve its local path for job A.")
            sendReq = SendMapRequest(jobAState, true, comm)
            jobAState.postponed = true
        else
            println("worker $rank created a local path of length $(length(jobA_solveResult))")
            jobASolved = true
            SendCompletedPath(jobA_solveResult, :pathA, comm)
        end

        # Check if Job B's supplement has come in the mail yet 
        if jobBState.postponed
            ReceiveAndProcessMapRequest!(availableTiles, comm, rank)
            println("Worker $rank has received its JobB map supplement")
        end

        jobB_solveResult = AStar_MPI_Opt1(availableTiles, maxX, maxY, jobBState)
        if jobB_solveResult === nothing
            println("Worker $rank needs more data to solve its local path for job B.")
            sendReq = SendMapRequest(jobBState, false, comm)
            jobBState.postponed = true
        else
            println("worker $rank created a local path of length $(length(jobB_solveResult))")
            jobBSolved = true
            SendCompletedPath(jobB_solveResult, :pathB, comm)
        end

        # Check if Job A's supplement has come in the mail yet.
        if jobAState.postponed
            ReceiveAndProcessMapRequest!(availableTiles, comm, rank)
            println("Worker $rank has received its JobA map supplement")
        end
    end

    # TODO: Job C and D, the beautification pass



    println("Worker $rank is done.")
end





function SendMapRequest(jobState::WorkerPathfindingState, isWayPointA::Bool, comm)::MPI.Request
    mapRequest::MPI_Opt1_MapRequest = MPI_Opt1_MapRequest(jobState.startTile, jobState.endTile, isWayPointA)
    sendRequest::MPI.Request = MPI.Isend(mapRequest, comm, dest=0, tag=MPI_OPT1_MAP_REQUEST)
    return sendRequest
end



# TODO: Implement
function ReceiveAndProcessMapRequest!(availableTiles::Dict{Tuple{Int32,Int32},MapTile}, comm, rank)

    mapSupplyStatus = MPI.Probe(comm, MPI.Status, source=0, tag=MPI_OPT1_MAP_RESPONSE_DELIVERY)
    incomingTilesSize = MPI.Get_count(mapSupplyStatus, MapTile)
    println("Worker $rank has received a probe signal for a map supplement\n Supposedly, the mapdata would have $incomingTilesSize elements")

    # println("Going to wait for the thing to come in soon")
    mapSupplyDelivery = Array{MapTile,1}(undef, incomingTilesSize)

    # I don't know why I can't get this to work with MPI.recv() now. Sad.
    # Since the probe was blocking, this recv can be blocking too. We already know the data is ready 
    incomingSupplyRequest = MPI.Irecv!(mapSupplyDelivery, comm; source=0, tag=MPI_OPT1_MAP_RESPONSE_DELIVERY)
    # println("WAiting for the read to go through")
    MPI.Wait(incomingSupplyRequest)

    println("Worker $rank received a new batch of tiles, with $(length(mapSupplyDelivery)) tiles.")

    # TODO: This is slow. Think of a smarter way of doing this.
    for suppliedTile::MapTile in mapSupplyDelivery
        if haskey(availableTiles, (suppliedTile.x, suppliedTile.y)) == false
            availableTiles[(suppliedTile.x, suppliedTile.y)] = suppliedTile
        end
    end
end









# // ::: -------------------------:: PATHFINDING ::------------------------- ::: // 
#
#
#
#
function AStar_MPI_Opt1(availableTiles::Dict{Tuple{Int32,Int32},MapTile}, maxX::Int32, maxY::Int32, state::WorkerPathfindingState)::Union{Array{MapTile},Nothing}

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

        neighborTilesExist = AStar_MPI_Opt1_GetNeighbors!()
        # This means "The Tile exists, but we haven't received it from the master core yet.
        if neighborTilesExist == false
            return nothing
        end

        for neighbor::MapTile in neighbors
            newCost = state.costSoFar[state.currentTile]
            if !haskey(state.costSoFar, neighbor) || newCost < state.costSoFar[neighbor]
                state.costSoFar[neighbor] = newCost
                priority = newCost + _heuristic(neighbor, state.endTile)
                state.frontier[neighbor] = priority
                state.cameFrom[neighbor] = state.currentTile
            end
        end
    end

    @assert foundEnd == true "Didn't find end, but got to the ConstructPath part regardless."


    return ConstructPath(state.endTile, state.startTile, state.cameFrom)
end












# // ::: -------------------------:: Map Gathering ::------------------------- ::: // 
#
#
#=
Idea: Take each point along the diagonal, and an arbitrary number of tiles above and below those diagonals.
Also extend this slightly to the left and the right.
=#
function GetEstimatedNecessaryCells(wayPointA::MapTile, wayPointB::MapTile, allTiles::Array{MapTile,2}, verticalEstimationSize::Int32, horizontalExtension::Int32, maxX::Int32, maxY::Int32)::Array{MapTile,1}
    # TODO: Support this for when wayPointB is BELOW or to the LEFT of wayPointA. Will need some adjustments to the math
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