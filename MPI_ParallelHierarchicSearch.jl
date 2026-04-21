

# This is not a smart function. The waypoints, while guaranteed to be reachable, may actually be walls (expensive to break), 
# and reaching them may be very expensive. Smoothing is necessary to make the path optimal.
function GenerateInitialWaypoints(startTile::MapTile, endTile::MapTile, coreCount::Int, allTiles::Dict{Tuple{Int,Int},MapTile})
    jumpX::Int = abs((endTile.x - startTile.x)) / coreCount
    jumpY::Int = abs((endTile.y - startTile.y)) / coreCount

    currentX::Int = startTile.x
    currentY::Int = startTile.y
    wayPoints::Array{MapTile} = [startTile]

    for i in 1:coreCount-1
        currentX += jumpX
        currentY += jumpY
        wayPoint::MapTile = allTiles[(currentX, currentY)]
        push!(wayPoints, wayPoint)
    end

    push!(wayPoints, endTile)
    for wayPoint in wayPoints
        wayPoint.color = :magenta
    end

    return wayPoints
end


function Test2(startTile::MapTile, endTile::MapTile)
    println("Test2 succeeded maybe? endTile y is $(endTile.y)")
end

function MPI_ParallelHierarchicSearch(startTile::MapTile, endTile::MapTile, allTiles::Dict{Tuple{Int,Int},MapTile})::Array{MapTile}
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



    # ::: -------------------------:: SOLVING INITIAL PATH ::------------------------- ::: 
    localPaths = Array{Array{MapTile},1}()
    for i in 1:length(wayPoints)-1
        localStartTile = wayPoints[i]
        localEndTile = wayPoints[i+1]

        push!(localPaths, st_AStar(localStartTile, localEndTile))
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
        push!(beautifiedLocalPaths, st_AStar(localStartTile, localEndTile))
    end
    # ::: -------------------------:: END OF BEAUTIFICATION ::------------------------- ::: 




    # ::: -------------------------:: FINAL PROCESSING ::------------------------- :::
    beautifiedFullPath::Array{MapTile} = reduce(vcat, beautifiedLocalPaths)
    fullPath::Array{MapTile} = reduce(vcat, localPaths)

    return beautifiedFullPath
    return fullPath
end
















