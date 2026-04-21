using DataStructures
using .CenAstar


function _fillWithNewNeighbors!(neighbors::Array{MapTile}, currentTile::MapTile, allTiles::Array{MapTile,2}, xMax, yMax)
    empty!(neighbors)
    northY = currentTile.y + 1
    if northY <= yMax
        northX = currentTile.x
        push!(neighbors, allTiles[northX, northY])
    end

    eastX = currentTile.x + 1
    if eastX <= xMax
        eastY = currentTile.y
        push!(neighbors, allTiles[eastX, eastY])
    end

    southY = currentTile.y - 1
    if southY >= 1
        southX = currentTile.x
        push!(neighbors, allTiles[southX, southY])
    end

    westX = currentTile.x - 1
    if westX >= 1
        westY = currentTile.y
        push!(neighbors, allTiles[westX, westY])
    end
end



function st_AStar(startTile::MapTile, endTile::MapTile, allTiles::Array{MapTile,2})::Array{MapTile}
    println("Starting the AStar pathfinding")

    xMax = size(allTiles, 1)
    yMax = size(allTiles, 2)
    # println("Going to search for endtile with x $(endTile.x) and y $(endTile.y)")

    frontier = PriorityQueue{MapTile,Int}()
    frontier[startTile] = 0

    cameFrom = Dict{MapTile,MapTile}()
    cameFrom[startTile] = MapTile(Int32(-99), Int32(-99))

    costSoFar = Dict{MapTile,Int64}()
    costSoFar[startTile] = 0

    neighbors = MapTile[]

    while isempty(frontier) == false
        currentTile::MapTile, _ = dequeue_pair!(frontier)
        if currentTile === endTile
            break
        end

        _fillWithNewNeighbors!(neighbors, currentTile, allTiles, xMax, yMax)
        for neighbor::MapTile in neighbors
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