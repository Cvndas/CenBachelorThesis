
function GenerateCoreAppropriateWaypoints(hardcodedWaypoints::Array{MapTile,1}, allTiles::Array{MapTile,2}, nranks)::Array{MapTile}
    workerCoreCount = nranks - 1

    println("Starting with $(length(hardcodedWaypoints)) waypoints, and going to divide them among $workerCoreCount cores")

    #= Idea: First form straight paths between each hardcoded waypoint. Load these into an array. Then grab 
             waypoints from this array.
    =#

    straightLine::Array{MapTile,1} = []

    # Forming straight lines from A to B
    for i in 1:length(hardcodedWaypoints)-1
        if hardcodedWaypoints[i].x < hardcodedWaypoints[i+1].x
            leftSide = hardcodedWaypoints[i]
            rightSide = hardcodedWaypoints[i+1]
        else
            leftSide = hardcodedWaypoints[i+1]
            rightSide = hardcodedWaypoints[i]
        end

        # Forming the straight line between these points
        ydif = rightSide.y - leftSide.y
        xdif = rightSide.x - leftSide.x

        yDifPerX::Float64 = Float64(ydif) / Float64(xdif)
        # println("From waypoint $leftSide to $rightSide, the yDifPerX is $yDifPerX")

        y = leftSide.y
        for x in (leftSide.x):(rightSide.x)
            push!(straightLine, allTiles[x, y])
            y = floor(Int32, Float64(y) + yDifPerX)
        end
        # println("Set up the waypoints for path $i and $(i + 1)")
    end
    println("Formed a straight line with $(length(straightLine)) points")

    #=
    Splitting up the straight line among all the workers, giving each worker 2 paths AB AB
    =#

    allWayPoints::Array{MapTile} = []
    push!(allWayPoints, straightLine[1])

    budget = length(straightLine)
    tilesPerCore = budget ÷ workerCoreCount
    tileIndex = 1
    for i in 1:workerCoreCount-1
        lastTileIndex = tileIndex + tilesPerCore
        if lastTileIndex > budget
            lastTileIndex = budget
        end
        halfwayIndex = lastTileIndex - tileIndex

        # wayPointA = straightLine[tileIndex]
        wayPointB = straightLine[halfwayIndex]
        # wayPointC = wayPointB
        wayPointD = straightLine[lastTileIndex]

        # push!(allWayPoints, wayPointA)
        push!(allWayPoints, wayPointB)
        # push!(allWayPoints, wayPointC)
        push!(allWayPoints, wayPointD)

        tileIndex = lastTileIndex
    end

    # For the last worker, let's do it manually to guarantee that the end tile is correct
    lastTileIndex = tileIndex + tilesPerCore
    if lastTileIndex > budget
        lastTileIndex = budget
    end
    halfwayIndex = lastTileIndex - tileIndex

    # push!(allWayPoints, straightLine[tileIndex])
    push!(allWayPoints, straightLine[halfwayIndex])
    # push!(allWayPoints, straightLine[halfwayIndex])
    push!(allWayPoints, straightLine[end])

    println("--- Created the core-appropriate waypoints. There are $(length(allWayPoints)) of them. In order:")
    display(allWayPoints)

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