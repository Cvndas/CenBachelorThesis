


function ConstructPath(endTile::MapTile, startTile::MapTile, cameFrom::Dict{MapTile,MapTile})::Array{MapTile}
    try
        constructedPath = MapTile[]
        currentPathTile = endTile
        push!(constructedPath, currentPathTile)
        while currentPathTile !== (startTile)
            currentPathTile = cameFrom[currentPathTile]
            push!(constructedPath, currentPathTile)
        end
        return constructedPath

    catch e
        println("Encountered an error in ConstructPath: $e")
        println("The cameFrom dict: ")
        for key in keys(cameFrom)
            mapTile::MapTile = cameFrom[key]
            if mapTile.x > 35 && mapTile.y > 35
                println("Entry with x: $(mapTile.x) and y: $(mapTile.y) and costToReach $(mapTile.costToReach))")
            end
        end
        error("ABORTING BECAUSE OF AN ERROR")
    end
end