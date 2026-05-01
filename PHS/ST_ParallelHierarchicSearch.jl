using MPI

# A reference function for how the MPI version should behave. Basically pseudocode that can be run.

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
        error("This func is old and probably doesn't work anymore, or is not representative of either the naive or opt1 PHS implementations.")
        # mazeImage = CenAstar.ShowMaze(computedMaze.wallMapTiles, computedMaze.pathMapTiles, computedMaze.mapBorders, shortestPathTiles, attemptedPathTiles)

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







function SingleThreaded_PHS_ReferenceFunc(startTile::MapTile, endTile::MapTile, allTiles::Array{MapTile,2})::Array{MapTile}
    println("Starting the MPI Ripple Search algorithm.")


    # ::: -------------------------:: GENERATING INITIAL WAYPOINTS ::------------------------- ::: 
    error("I changed the signature of GenerateInitialWaypoints. Check that this still works")
    wayPoints::Array{MapTile} = GenerateInitialWaypoints(startTile, endTile, coreCount + 1, allTiles)
    for (i, wayPoint) in enumerate(wayPoints)
        println("Waypoint $(i): x:$(wayPoint.x), y:$(wayPoint.y)")
    end
    # ::: -------------------------:: END OF GENERATING INITIAL WAYPOINTS ::------------------------- ::: 


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

