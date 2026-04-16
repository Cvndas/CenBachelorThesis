using DataStructures
include("Utilities.jl")

function ConstructPath(endTile::MapTile, startTile::MapTile, cameFrom::Dict{MapTile,MapTile})
    pathReversed = MapTile[]
    currentPathTile = endTile
    push!(pathReversed, currentPathTile)
    while currentPathTile != (startTile)
        currentPathTile = cameFrom[currentPathTile]
        push!(pathReversed, currentPathTile)
    end

    path = Tuple{Int64, Int64}[]
    for i in length(pathReversed):-1:1
        push!(path, (pathReversed[i].x, pathReversed[i].y))
    end

    println("The shortest path, as found by the single threaded A* algorithm: ")
    display(path)
    return path
end

function st_AStar(walls::Array{MapTile}, startTile::MapTile, endTile::MapTile)::Array{Tuple{Int64, Int64}}
    println("Starting the AStar pathfinding")

    frontier = PriorityQueue{MapTile, Int}()
    frontier[startTile] = 0 

    cameFrom = Dict{MapTile, MapTile}()
    cameFrom[startTile] = MapTile(-99, -99)

    costSoFar = Dict{MapTile, Int64}()
    costSoFar[startTile] = 0

    while isempty(frontier) == false
        currentTile, _ = dequeue_pair!(frontier)
        if currentTile == endTile
            break
        end

        neighbors = MapTile_GetNeighbors(currentTile, walls)
        for neighbor in neighbors
            newCost = costSoFar[currentTile] + neighbor.costToReach
            if !haskey(costSoFar, neighbor) || newCost < costSoFar[neighbor]
                costSoFar[neighbor] = newCost
                priority = newCost + _heuristic(neighbor, endTile)
                frontier[neighbor] = priority
                cameFrom[neighbor] = currentTile
            end
        end
        # println("Grabbed element from the frontier: $currentTile")
    end

    println("Done the full pathfinding. Frontier is empty.")
    return ConstructPath(endTile, startTile, cameFrom)

end




function _heuristic(a::MapTile, b::MapTile)
    return abs(a.x - b.x) + abs(a.y - b.y)
end