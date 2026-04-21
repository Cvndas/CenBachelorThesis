using MPI

#=

The main challenge of this is the fact that memory is not shared across the processors.
With a shared memory architecture, all cores could efficiently read the full maze.
With MPI, this is inefficient, and the cores need to receive as small of a chunk of data
as needed. This is the one major opportunity for optimization.

My idea, for now, is to start with an estimate of what search area each core needs. 
If the core needs more, it sends a request to the master core, and hopefully receives
the remaining data within a short enough timeframe.

By the time the beautification iteration comes around, much if not all of the map data
that is necessary for the beautification pass should already be present in the core
that handles this area of the maze.

To deal with the latency of requesting and receiving new map data, each core will 
be assigned with two paths to solve. Initially, the core solves path A. If it
needs more data, it sends a request, then solves path B. After solving B, it 
returns to path A, at which point it hopefully has the new chunk ready. 

If it is in path B and it needs more data, it returns to path A. If it needs more data in A,
it returns to B, etc.

After the first user reports needing more tiles to work with, the master should probably
just permanently double how much it sends to everyone from there onward.

=#



# This is not a smart function. The waypoints, while guaranteed to be reachable, may actually be walls (expensive to break), 
# and reaching them may be very expensive. Smoothing is necessary to make the path optimal.
function GenerateInitialWaypoints(startTile::MapTile, endTile::MapTile, coreCount::Int, allTiles::Array{MapTile,2})
    jumpX::Int = abs((endTile.x - startTile.x)) ÷ coreCount
    jumpY::Int = abs((endTile.y - startTile.y)) ÷ coreCount

    currentX::Int = startTile.x
    currentY::Int = startTile.y
    wayPoints::Array{MapTile} = [startTile]

    for i in 1:coreCount-2
        currentX += jumpX
        currentY += jumpY
        wayPoint::MapTile = allTiles[currentX, currentY]
        push!(wayPoints, wayPoint)
    end

    push!(wayPoints, endTile)

    return wayPoints
end




ComputePathCost = path -> sum(tile.costToReach for tile::MapTile in path)




mutable struct MPI_MapData
    deliveryTiles::Array{MapTile,2}
end

const INITIAL_DELIVERY = 0
const INITIAL_WAYPOINTS = 1
const LOCAL_PATH_DELIVERY = 2

function MPI_PHS_Entry(comm, nranks, rank, host)
    if rank == 0
        println("Entered MPI_PHS_Entry()")
        CenAstar.Initialize() # only initializes the seed, for now.
        computedMaze::ComputedMaze = ComputeMaze()
        initialMapData::MPI_MapData = MPI_MapData(computedMaze.allTiles)
    end

    # Wait for the maze to be generated
    MPI.Barrier(comm)
    if rank == 0
        # TODO: Make this an ISend, of course, to latency hide the landmark computations
        println("The maze is ready. Rank 0 is sending it to all other cores now.")
        for recipient in 1:nranks-1
            MPI.send(initialMapData, comm; dest=recipient, tag=INITIAL_DELIVERY)
        end

        initialWayPoints::Array{MapTile} = GenerateInitialWaypoints(computedMaze.startTile, computedMaze.endTile, nranks, computedMaze.allTiles)
        for (i, wayPoint) in enumerate(initialWayPoints)
            println("Waypoint $i is ($(wayPoint.x), $(wayPoint.y)))")
        end

        for i in 1:nranks-1
            MPI.send((initialWayPoints[i], initialWayPoints[i+1]), comm; dest=i, tag=INITIAL_WAYPOINTS)
            println("Sent waypoints $i and $(i + 1) to recipient $i")
        end

        localPaths::Array{Array{MapTile,1},1} = Array{Array{MapTile,1},1}()
        for rank in 1:nranks-1
            (localPath::Array{MapTile}, status) = MPI.recv(MPI.ANY_SOURCE, LOCAL_PATH_DELIVERY, comm)
            push!(localPaths, localPath)
            println("Master rank received a local path with $(length(localPath)) maptiles from $(status.source) with tag $(status.tag)")
        end
        println("Master rank received all the local paths that are necessary.")
        fullPath::Array{MapTile,1} = reduce(vcat, localPaths)

        cost = ComputePathCost(fullPath)

        println("\n--- THE RESULTS ---\n")
        println("Reconstructed the full path, which has cost $cost")

        _ = CenAstar.ShowMaze(computedMaze.wallMapTiles, computedMaze.pathMapTiles, computedMaze.mapBorders, fullPath, MapTile[])

    else
        (receivedInitialMapData::MPI_MapData, status::MPI.Status) = MPI.recv(0, INITIAL_DELIVERY, comm)
        println("I'm rank $rank and I received $(length(receivedInitialMapData.deliveryTiles)) tiles from $(status.source), with tag $(status.tag)")

        (receivedInitialWayPoints::Tuple{MapTile,MapTile}, status) = MPI.recv(0, INITIAL_WAYPOINTS, comm)
        println("I'm rank $rank and I received $(length(receivedInitialWayPoints)) waypoints from $(status.source), with tag $(status.tag)")
        wayPointA::MapTile = receivedInitialWayPoints[1]
        wayPointB::MapTile = receivedInitialWayPoints[2]
        localStartPoint = receivedInitialMapData.deliveryTiles[wayPointA.x, wayPointA.y]
        localEndPoint = receivedInitialMapData.deliveryTiles[wayPointB.x, wayPointB.y]
        # IMPORTANT: Pathfinding relies on the references of MapTiles being sourced from the received mapdata, with the waypoints merely serving as
        # indices into the array

        # Ready to start solving the path.
        localPath = st_AStar(localStartPoint, localEndPoint, receivedInitialMapData.deliveryTiles)
        println("I'm rank $rank and I solved my local path. Sending it back to the master core")
        MPI.send(localPath, comm; dest=0, tag=LOCAL_PATH_DELIVERY)
        println("I'm rank $rank and I sent back my local path to the master core.")
    end


    if rank == 0
        println("Press enter to exit")
        readline()
        # fig = Figure()
        println("Done with main().")
    end
end



function SingleThreaded_PHS_ReferenceFunc_Entry(comm, nranks, rank, host)

    if rank == 0
        CenAstar.Initialize()
        println("Entered main_MPI_ParallelHierarchicSearch()")
        computedMaze::ComputedMaze = ComputeMaze()
        # allPathsDict = Dict{Tuple{Int,Int},MapTile}()
        # for mapTile in computedMaze.traversablePaths
        #     allPathsDict[(mapTile.x, mapTile.y)] = mapTile
        # end

        shortestPathTiles = SingleThreaded_PHS_ReferenceFunc(computedMaze.startTile, computedMaze.endTile, computedMaze.allTiles)
        attemptedPathTiles = MapTile[]

        println("Path is done. Going to render the maze now.")
        mazeImage = CenAstar.ShowMaze(computedMaze.wallMapTiles, computedMaze.pathMapTiles, computedMaze.mapBorders, shortestPathTiles, attemptedPathTiles)

        mpiPhsCost = ComputePathCost(shortestPathTiles)

        println("\n--- THE RESULTS ---\n")
        println("MPI PHS found a path with cost $mpiPhsCost")
    end

    MPI.Barrier(comm)
    # After the barrier, the maze should be created, but no data from the maze should be shared with any of
    # the other cores yet.
    println("I'm rank $rank and I'm done with the barrier! I acknowledge that the maze is ready.")


    if rank == 0
        println("Press enter to exit")
        readline()
        # fig = Figure()
        println("Done with main().")
    end

    MPI.Finalize()
end







# A reference function for how the MPI version should behave. Basically pseudocode that can be run.
function SingleThreaded_PHS_ReferenceFunc(startTile::MapTile, endTile::MapTile, allTiles::Array{MapTile,2})::Array{MapTile}
    println("Starting the MPI Ripple Search algorithm.")


    # ::: -------------------------:: SETUP ::------------------------- ::: 
    # Hard-coding this for now
    coreCount::Int = 4
    # ::: -------------------------:: END OF SETUP ::------------------------- ::: 



    # ::: -------------------------:: GENERATING INITIAL WAYPOINTS ::------------------------- ::: 
    wayPoints::Array{MapTile} = GenerateInitialWaypoints(startTile, endTile, coreCount, allTiles)
    for (i, wayPoint) in enumerate(wayPoints)
        println("Waypoint $(i): x:$(wayPoint.x), y:$(wayPoint.y)")
    end
    # ::: -------------------------:: END OF GENERATING INITIAL WAYPOINTS ::------------------------- ::: 

    #= 
    TODO
    Idea: The initial path construction is easy. But then, smoothing needs to be done. This may 
    need some coordination. Doing smoothing in such a way that it's actually saving time 
    while getting reasonably close to the single threaded A*. While some may still be pathfinding, start
    the smoothing process on cores that are already done
    =#

    #=
    TODO IDEA:
    Sending the entire maze to all participants could be very expensive. Maybe send only a chunk that is
    likely to be necessary. If more is required, send more chunks, or expand the existing chunk
    =#


    # ::: -------------------------:: SOLVING INITIAL PATH ::------------------------- ::: 
    localPaths = Array{Array{MapTile},1}()
    for i in 1:length(wayPoints)-1
        localStartTile = wayPoints[i]
        localEndTile = wayPoints[i+1]

        push!(localPaths, st_AStar(localStartTile, localEndTile, allTiles))
    end
    # ::: -------------------------:: END OF SOLVING INITIAL PATH ::------------------------- ::: 




    # ::: -------------------------:: BEAUTIFICATION ::------------------------- ::: 
    beautificationWaypoints = [startTile]
    GetMiddlePoint = function (path::Array{MapTile})
        middleIndex = length(path) ÷ 2
        @assert typeof(middleIndex) == Int "middleIndex had wrong type"
        return path[middleIndex]
    end
    for path in localPaths
        push!(beautificationWaypoints, GetMiddlePoint(path))
    end
    push!(beautificationWaypoints, endTile)

    # The beautification waypoints produced one more waypoint than there was before.
    beautifiedLocalPaths = Array{Array{MapTile},1}()
    for i in 1:length(beautificationWaypoints)-1
        localStartTile = beautificationWaypoints[i]
        localEndTile = beautificationWaypoints[i+1]
        push!(beautifiedLocalPaths, st_AStar(localStartTile, localEndTile, allTiles))
    end
    # ::: -------------------------:: END OF BEAUTIFICATION ::------------------------- ::: 




    # ::: -------------------------:: FINAL PROCESSING ::------------------------- :::
    beautifiedFullPath::Array{MapTile} = reduce(vcat, beautifiedLocalPaths)
    fullPath::Array{MapTile} = reduce(vcat, localPaths)

    return beautifiedFullPath
    return fullPath
end
















