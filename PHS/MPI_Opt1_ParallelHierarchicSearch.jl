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
const MPI_OPT1_PATH_DELIVERY = 4

mutable struct MPI_Opt1_Job
    wayPointA::MapTile
    wayPointB::MapTile
end



mutable struct MPI_Opt1_JobRequest
    jobA::MPI_Opt1_Job
    jobB::MPI_Opt1_Job
end




# mutable struct MPI_Opt1_PhsMapData
#     mapDelivery::Array{MapTile,1}
# end




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
        println("All cores are done with the PHS Procedure. Exiting...")
    end
end

function MPI_Opt1_PhsMasterCore(comm, nranks, rank, host, computedMaze::ComputedMaze)
    # TODO: Lower this to a small number to test that the technique works
    verticalEstimationSize::Int32 = 3
    horizontalExtensionSize::Int32 = 3

    maxX::Int32 = Int32(size(computedMaze.allTiles, 1))
    maxY::Int32 = Int32(size(computedMaze.allTiles, 2))

    # Let's first generate some waypoints, as these determine what data the workers need
    wayPoints::Array{MapTile} = GenerateInitialWaypoints(computedMaze.startTile, computedMaze.endTile, nranks * 2, computedMaze.allTiles)
    paths::Vector{Tuple{MapTile,MapTile}} = Tuple{MapTile,MapTile}[]
    for i in 1:length(wayPoints)-1
        push!(paths, (wayPoints[i], wayPoints[i+1]))
    end

    println("The following paths were created")
    for path in paths
        println("A: $(path[1]) to B: $(path[2])")
    end

    pendingSends::Vector{MPI.Request} = MPI.Request[]
    for i in 1:length(paths)-2
        pathA = paths[i]
        pathA_estimatedNecessaryCells::Array{MapTile,1} =
            GetEstimatedNecessaryCells(pathA[1], pathA[2], computedMaze.allTiles, verticalEstimationSize, horizontalExtensionSize, maxX, maxY)

        pathB = paths[i+1]
        pathB_estimatedNecessaryCells::Array{MapTile,1} =
            GetEstimatedNecessaryCells(pathB[1], pathB[2], computedMaze.allTiles, verticalEstimationSize, horizontalExtensionSize, maxX, maxY)

        both_estimatedNecessaryCells::Array{MapTile,1} = unique(vcat(pathA_estimatedNecessaryCells, pathB_estimatedNecessaryCells))
        # @assert isbits(both_estimatedNecessaryCells) "initial map data was not bits"

        println("Created the necessary cells for paths $i and $(i+1) which has length $(length(both_estimatedNecessaryCells))")
        # if i == 1
        #     println("The estimated necessary cells of the first path: $(values(pathA_estimatedNecessaryCells))")
        # end

        workerRank = i

        # mapDataForWorker::MPI_Opt1_PhsMapData = MPI_Opt1_PhsMapData(both_estimatedNecessaryCells)
        println("The map data for worker $workerRank has $(length(both_estimatedNecessaryCells)) elements")
        # push!(pendingSends, MPI.Isend(both_estimatedNecessaryCells, comm; dest=workerRank, tag=MPI_OPT1_MAP_INITIAL_DELIVERY))
        MPI.send(both_estimatedNecessaryCells, comm; dest=workerRank, tag=MPI_OPT1_MAP_INITIAL_DELIVERY)

        jobA::MPI_Opt1_Job = MPI_Opt1_Job(pathA[1], pathB[2])
        jobB::MPI_Opt1_Job = MPI_Opt1_Job(pathB[1], pathB[2])
        jobsForWorker::MPI_Opt1_JobRequest = MPI_Opt1_JobRequest(jobA, jobB)
        # push!(pendingSends, MPI.Isend(jobsForWorker, comm; dest=workerRank, tag=MPI_OPT1_JOB_REQUEST))
    end

    println("Sent off all the jobs and mapdata to the workers.")
    for pendingSend::MPI.Request in pendingSends
        MPI.Wait(pendingSend)
        (completed, status) = MPI.Test(pendingSend)
        @assert completed == true "Somehow completed was false after calling .Wait() on it"
        println("One of the pending sends has been completed::: source: $(status.MPI_SOURCE), tag: $(status.MPI_TAG)")
    end




end

function MPI_Opt1_WorkerCore(comm, nranks, rank, host)
    # # The first thing we expect is the initial path delivery
    # initialMapDataDelivery_Ref = Ref{MPI_Opt1_PhsMapData}()
    # initialMapDataDelivery_MPIRequest = MPI.Irecv!(initialMapDataDelivery_Ref, comm; source=0, tag=MPI_OPT1_MAP_INITIAL_DELIVERY)

    # initialJobRequest_Ref = Ref{MPI_Opt1_JobRequest}()
    # initialJobRequest_MPIRequest = MPI.Irecv!(initialJobDelivery_Ref, comm; source=0, tag=MPI_OPT1_JOB_REQUEST)

    # MPI.Wait(initialMapDataDelivery_MPIRequest)
    # initialMapDataDelivery::MPI_Opt1_PhsMapData = initialMapDataDelivery_Ref[] # dereference it 
    # println("Worker $rank received the initial map data delivery, which has $(length(initialMapDataDelivery.mapDelivery)) map tiles")

    # MPI.Wait(initialJobRequest_MPIRequest)
    # initialJobRequest::MPI_Opt1_JobRequest = initialJobRequest_Ref[]
    # jobA::MPI_Opt1_Job = initialJobRequest.jobA
    # jobB::MPI_Opt1_Job = initialJobRequest.jobB
    # println("Worker $rank received the initial job request, which has map tiles $(jobA.wayPointA) and $(jobA.wayPointB) for job A, and map tiles $(jobB.wayPointA) and $(jobB.wayPointB) for job B")

    # println("Worker $rank is done.")
end




# TODO: A custom A* parallel search, that uses dictionary instead of matrix array, and 
# which allows for an abort, saving the state, and returning later

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