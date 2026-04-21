using MPI

# This is not a smart function. The waypoints, while guaranteed to be reachable, may actually be walls (expensive to break), 
# and reaching them may be very expensive. Smoothing is necessary to make the path optimal.
function GenerateInitialWaypoints(startTile::MapTile, endTile::MapTile, coreCount::Int, allTiles::Array{MapTile,2})
    jumpX::Int = abs((endTile.x - startTile.x)) ÷ coreCount
    jumpY::Int = abs((endTile.y - startTile.y)) ÷ coreCount

    currentX::Int = startTile.x
    currentY::Int = startTile.y
    wayPoints::Array{MapTile} = [startTile]

    for i in 1:coreCount-1
        currentX += jumpX
        currentY += jumpY
        wayPoint::MapTile = allTiles[currentX, currentY]
        push!(wayPoints, wayPoint)
    end

    push!(wayPoints, endTile)

    return wayPoints
end


function Test2(startTile::MapTile, endTile::MapTile)
    println("Test2 succeeded maybe? endTile y is $(endTile.y)")
end

const MASTER_RANK = 0
function MPI_PHS_Entry(comm, nranks, rank, host)

    if rank == MASTER_RANK
        CenAstar.Initialize()
        println("Entered main_MPI_ParallelHierarchicSearch()")
        computedMaze::ComputedMaze = ComputeMaze()
        # allPathsDict = Dict{Tuple{Int,Int},MapTile}()
        # for mapTile in computedMaze.traversablePaths
        #     allPathsDict[(mapTile.x, mapTile.y)] = mapTile
        # end

        shortestPathTiles = MPI_ParallelHierarchicSearch(computedMaze.startTile, computedMaze.endTile, computedMaze.allTiles)
        attemptedPathTiles = MapTile[]

        println("Path is done. Going to render the maze now.")
        mazeImage = CenAstar.ShowMaze(computedMaze.wallMapTiles, computedMaze.pathMapTiles, computedMaze.mapBorders, shortestPathTiles, attemptedPathTiles)

        ComputePathCost = path -> sum(tile.costToReach for tile::MapTile in path)
        mpiPhsCost = ComputePathCost(shortestPathTiles)

        println("\n--- THE RESULTS ---\n")
        println("MPI PHS found a path with cost $mpiPhsCost")

        # TODO: Wait for the master rank to produce the maze. Like a barrier. Or maybe all should produce the maze, then
        # wait for the barrier.
    end

    MPI.Barrier(comm)
    println("I'm rank $rank and I'm done with the barrier!")


    if rank == MASTER_RANK
        println("Press enter to exit")
        readline()
        # fig = Figure()
        println("Done with main().")
    end

    MPI.Finalize()
end

function MPI_ParallelHierarchicSearch(startTile::MapTile, endTile::MapTile, allTiles::Array{MapTile,2})::Array{MapTile}
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
















