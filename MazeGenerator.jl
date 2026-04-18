include("Utilities.jl")



function _MakeEndTileReachable!(path, walls, evacuationVisited, currentEvacuator, xMin, xMax, yMin, yMax)
    neighbors = GetNeighbors(currentEvacuator, xMin, xMax, yMin, yMax)

    filter!(x -> !(x in evacuationVisited), neighbors)
    if isempty(neighbors)
        error("Didn't find any neighbors in the process of making the end tile reachable")
    end

    for neighbor in neighbors
        if neighbor in path
            println("Made the end tile reachable.")
            return true
        end
    end

    for neighbor in neighbors
        currentEvacuator = neighbor
        push!(evacuationVisited, currentEvacuator)
        success = _MakeEndTileReachable!(path, walls, evacuationVisited, currentEvacuator, xMin, xMax, yMin, yMax)
        if success
            return true
        end
    end

    return false
end

function MakeEndTileReachable!(path, walls, endTile, xMin, xMax, yMin, yMax)
    evacuationVisited = Set{Tuple{Int,Int}}()
    push!(evacuationVisited, endTile)

    currentEvacuator = endTile
    success = _MakeEndTileReachable!(path, walls, evacuationVisited, currentEvacuator, xMin, xMax, yMin, yMax)

    @assert success "Failed to make tile reachable"

    for evac in evacuationVisited
        push!(path, evac)
        filter!(x -> x != evac, walls)
    end
end

function PrimsMazeGenerator(xMin, xMax, yMin, yMax)


    frontier = Set{Tuple{Int,Int}}()
    path = Set{Tuple{Int,Int}}()

    startTile = (xMin, yMin)
    endTile = (xMax, yMax)

    push!(path, startTile)
    AddNeighbors!(frontier, path, startTile, xMin, xMax, yMin, yMax)

    currentTile = startTile
    while isempty(frontier) == false
        candidateFromFrontier = rand(collect(frontier))
        pathNeighborCount = 0

        delete!(frontier, candidateFromFrontier)

        north = (candidateFromFrontier[1], candidateFromFrontier[2] + 1)
        east = (candidateFromFrontier[1] + 1, candidateFromFrontier[2])
        south = (candidateFromFrontier[1], candidateFromFrontier[2] - 1)
        west = (candidateFromFrontier[1] - 1, candidateFromFrontier[2])

        if north in path
            pathNeighborCount += 1
        end
        if east in path
            pathNeighborCount += 1
        end
        if south in path
            pathNeighborCount += 1
        end
        if west in path
            pathNeighborCount += 1
        end

        if pathNeighborCount == 1
            # println("Added tile $candidateFromFrontier to the path")
            push!(path, candidateFromFrontier)
            AddNeighbors!(frontier, path, candidateFromFrontier, xMin, xMax, yMin, yMax)
        end
    end


    walls = Tuple{Int,Int}[]
    for x in xMin:xMax, y in yMin:yMax
        if !((x, y) in path)
            push!(walls, (x, y))
        end
    end

    # Break walls until one of the endtile's neighbors is a path
    if !(endTile in path)
        MakeEndTileReachable!(path, walls, endTile, xMin, xMax, yMin, yMax)
    end

    @assert endTile in path "End tile was not in path"
    @assert !(endTile in walls) "End tile was not in walls"

    # println("The path: ")
    # display(path)
    println("Generated a maze via prims algorithm.")

    # Surrouding the play area with walls.
    for x in (xMin-1:xMax+1)
        push!(walls, (x, yMin - 1))
        push!(walls, (x, yMax + 1))
    end

    for y in yMin:yMax
        push!(walls, (xMin - 1, y))
        push!(walls, (xMax + 1, y))
    end

    return walls
end


function PunctureHoles!(points)
    wallsBefore = length(points)
    filter!(x -> rand(1:100) > 20, points)
    wallsAfter = length(points)
    holesPunctured = wallsBefore - wallsAfter
    println("Punctured $holesPunctured holes into the wall, reducing the number of wall tiles from $wallsBefore to $wallsAfter")
end


function IsInBounds(point::Tuple{Int,Int}, xMin, xMax, yMin, yMax)
    return point[1] >= xMin && point[1] <= xMax && point[2] >= yMin && point[2] <= yMax
end



function AddNeighborMaybe!(frontier, path, neighbor, xMin, xMax, yMin, yMax)
    if !(neighbor in path) && !(neighbor in frontier) && IsInBounds(neighbor, xMin, xMax, yMin, yMax)
        push!(frontier, neighbor)
    end
end

function AddNeighbors!(frontier, path, tile, xMin, xMax, yMin, yMax)
    north = (tile[1], tile[2] + 1)
    east = (tile[1] + 1, tile[2])
    south = (tile[1], tile[2] - 1)
    west = (tile[1] - 1, tile[2])

    AddNeighborMaybe!(frontier, path, north, xMin, xMax, yMin, yMax)
    AddNeighborMaybe!(frontier, path, east, xMin, xMax, yMin, yMax)
    AddNeighborMaybe!(frontier, path, south, xMin, xMax, yMin, yMax)
    AddNeighborMaybe!(frontier, path, west, xMin, xMax, yMin, yMax)
end


function GetNeighbors(tile, xMin, xMax, yMin, yMax)
    north = (tile[1], tile[2] + 1)
    east = (tile[1] + 1, tile[2])
    south = (tile[1], tile[2] - 1)
    west = (tile[1] - 1, tile[2])

    neighbors = Tuple{Int,Int}[]

    if IsInBounds(north, xMin, xMax, yMin, yMax)
        push!(neighbors, north)
    end
    if IsInBounds(east, xMin, xMax, yMin, yMax)
        push!(neighbors, east)
    end
    if IsInBounds(south, xMin, xMax, yMin, yMax)
        push!(neighbors, south)
    end
    if IsInBounds(west, xMin, xMax, yMin, yMax)
        push!(neighbors, west)
    end

    return neighbors

end
