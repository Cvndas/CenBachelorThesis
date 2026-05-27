

function _MoveOffWalls(straightLine::Array{MapTile,1}, originalIndex, minIndex, maxIndex)
    safeIndex = originalIndex

    diff = 1

    while straightLine[safeIndex].costToReach == PATHCOST_Wall
        safeIndex += diff
        if safeIndex > maxIndex
            safeIndex = originalIndex - 1
            diff = -1
        end

        if safeIndex < minIndex
            println("BAD: Was unable to find a non-wall tile in straight line between $minIndex and $maxIndex")
            return originalIndex
        end
    end

    difference = abs(originalIndex - safeIndex)
    println("Moving waypoitns off walls: The positional change is $difference")


    return safeIndex
end

function GenerateCoreAppropriateWaypoints(hardcodedWaypoints::Array{MapTile,1}, allTiles::Array{MapTile,2}, nranks)::Array{MapTile}
    workerCoreCount = nranks - 1

    println("Starting with $(length(hardcodedWaypoints)) waypoints, and going to divide them among $workerCoreCount cores")
    display(hardcodedWaypoints)

    #= Idea: First form straight paths between each hardcoded waypoint. Load these into an array. Then grab 
             waypoints from this array.
    =#


    #=
    This idea for forming a straight line is so much simpler than dealing with floating points->int conversions
    Only downside is that unless the waypoints are exactly on a diagonal from one another, the straight line
    will first go at a 45 degree angle, then go straight up/down or straight left/right
    =#

    # TODO NEXT SESH:
    #=
        If way point is in a wall, move forward/backward along the straight line until a non-wall block is found.
    =#

    straightLine::Array{MapTile,1} = []

    goUp::Bool = true
    # Forming straight lines from A to B
    for i in 1:length(hardcodedWaypoints)-1

        A::MapTile = hardcodedWaypoints[i]
        B::MapTile = hardcodedWaypoints[i+1]
        xDir::Int32 = if A.x < B.x
            1
        else
            -1
        end

        yDir::Int32 = if A.y < B.y
            1
        else
            -1
        end

        current::Tuple{Int32,Int32} = (A.x, A.y)
        target::Tuple{Int32,Int32} = (B.x, B.y)

        push!(straightLine, allTiles[current[1], current[2]])

        while current != target
            if goUp
                current = (current[1], current[2] + yDir)
            else
                current = (current[1] + xDir, current[2])
            end

            push!(straightLine, allTiles[current[1], current[2]])

            if goUp && current[1] != target[1]
                goUp = false
            elseif !goUp && current[2] != target[2]
                goUp = true
            end
        end
        # println("Set up the waypoints for path $i and $(i + 1)")
    end
    println("Formed a straight line with $(length(straightLine)) points")
    @assert straightLine[end] == hardcodedWaypoints[end] "Straight line end is not hardcoded end. sl: $(straightLine[end]), hc: $(hardcodedWaypoints[end]). The straight line: $straightLine"

    #=
    Splitting up the straight line among all the workers, giving each worker 2 paths AB AB
    =#

    allWayPoints::Array{MapTile} = []
    push!(allWayPoints, straightLine[1])

    straightLineLen = length(straightLine)
    tilesPerCore = straightLineLen ÷ workerCoreCount
    tileIndex = 1
    for i in 1:workerCoreCount-1
        lastTileIndex = tileIndex + tilesPerCore
        if lastTileIndex > straightLineLen
            lastTileIndex = straightLineLen
        end
        halfwayIndex = lastTileIndex - tileIndex

        # wayPointA = straightLine[tileIndex]
        pointBIndex = _MoveOffWalls(straightLine, halfwayIndex, tileIndex, lastTileIndex - 1)
        wayPointB::MapTile = straightLine[pointBIndex]
        # wayPointC = wayPointB

        pointDIndex = _MoveOffWalls(straightLine, lastTileIndex, pointBIndex + 1, lastTileIndex)
        wayPointD::MapTile = straightLine[pointDIndex]

        # Guaranteeing that these waypoints are not in walls

        # push!(allWayPoints, wayPointA)
        push!(allWayPoints, wayPointB)
        # push!(allWayPoints, wayPointC)
        push!(allWayPoints, wayPointD)

        tileIndex = lastTileIndex
    end

    # For the last worker, let's do it manually to guarantee that the end tile is correct
    lastTileIndex = tileIndex + tilesPerCore
    if lastTileIndex > straightLineLen
        lastTileIndex = straightLineLen
    end
    halfwayIndex = lastTileIndex - tileIndex

    # push!(allWayPoints, straightLine[tileIndex])
    push!(allWayPoints, straightLine[halfwayIndex])
    # push!(allWayPoints, straightLine[halfwayIndex])
    push!(allWayPoints, straightLine[end])

    println("--- Created the core-appropriate waypoints. There are $(length(allWayPoints)) of them. In order:")
    display(allWayPoints)

    @assert allWayPoints[1] == hardcodedWaypoints[1] && allWayPoints[end] == hardcodedWaypoints[end] "hardcoded start: $(hardcodedWaypoints[1]) and core-appropriate start: $(allWayPoints[1]), hardcoded end: $(hardcodedWaypoints[end]) and core-appropriate end: $(allWayPoints[end])"

    return allWayPoints
end




# This is not a smart function. The waypoints, while guaranteed to be reachable, may actually be walls (expensive to break), 
# and reaching them may be very expensive. Smoothing is necessary to make the path optimal.
function GenerateInitialWaypoints(startTile::MapTile, endTile::MapTile, pathCount::Int, allTiles::Array{MapTile,2})
    jumpX::Int = abs((endTile.x - startTile.x)) ÷ pathCount
    jumpY::Int = abs((endTile.y - startTile.y)) ÷ pathCount

    currentX::Int = startTile.x
    currentY::Int = startTile.y
    wayPoints::Array{MapTile} = [startTile]

    for i in 1:pathCount-1
        currentX += jumpX
        currentY += jumpY
        wayPoint::MapTile = allTiles[currentX, currentY]
        push!(wayPoints, wayPoint)
    end

    push!(wayPoints, endTile)

    return wayPoints
end




ComputePathCost = path -> sum(tile.costToReach for tile::MapTile in path)