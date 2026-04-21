


function ConstructPath(endTile::MapTile, startTile::MapTile, cameFrom::Dict{MapTile,MapTile})::Array{MapTile}
    path = MapTile[]
    currentPathTile = endTile
    push!(path, currentPathTile)
    while currentPathTile != (startTile)
        currentPathTile = cameFrom[currentPathTile]
        push!(path, currentPathTile)
    end
    reverse!(path)

    for tile in path
        ConvertToTraversed!(tile)
    end

    return path
end