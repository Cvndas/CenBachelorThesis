using DataStructures
using .CenAstar




function st_AStar(startTile::MapTile, endTile::MapTile)::Array{MapTile}
    println("Starting the AStar pathfinding")
    # println("Going to search for endtile with x $(endTile.x) and y $(endTile.y)")

    frontier = PriorityQueue{MapTile,Int}()
    frontier[startTile] = 0

    cameFrom = Dict{MapTile,MapTile}()
    cameFrom[startTile] = MapTile(-99, -99)

    costSoFar = Dict{MapTile,Int64}()
    costSoFar[startTile] = 0

    while isempty(frontier) == false
        currentTile::MapTile, _ = dequeue_pair!(frontier)
        if currentTile === endTile
            break
        end

        for neighbor::MapTile in currentTile.neighbors
            newCost = costSoFar[currentTile] + neighbor.costToReach
            if !haskey(costSoFar, neighbor) || newCost < costSoFar[neighbor]
                costSoFar[neighbor] = newCost
                priority = newCost + _heuristic(neighbor, endTile)
                frontier[neighbor] = priority
                cameFrom[neighbor] = currentTile
            end
        end
    end

    println("Done the full pathfinding. Constructing the path now.")
    return ConstructPath(endTile, startTile, cameFrom)

end




function _heuristic(a::MapTile, b::MapTile)
    return abs(a.x - b.x) + abs(a.y - b.y)
end