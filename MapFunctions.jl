
function LoadMap(mapName::String)

    dir = "Custom Maps"
    path = joinpath(dir, mapName * ".map")

    loaded::SavedMaze = open(path, "r") do file
        deserialize(file)
    end

    wayPoints::Array{MapTile,1} = []

    traversablePaths_Dict = Dict{Tuple{Int32,Int32},MapTile}()

    allMapTiles::Array{MapTile,2} = Array{MapTile,2}(undef, loaded.xMax, loaded.yMax)

    for mutableMapTile in loaded.mapTiles
        asImmutable::MapTile = MakeImmutable(mutableMapTile)
        # push!(traversablePaths, asImmutable)
        traversablePaths_Dict[(mutableMapTile.x, mutableMapTile.y)] = asImmutable

        allMapTiles[mutableMapTile.x, mutableMapTile.y] = asImmutable
    end

    WayPointExists = (wayPoint::Tuple{Int32,Int32}) -> wayPoint[1] >= 1 && wayPoint[2] >= 1
    for wayPoint::Tuple{Int32,Int32} in loaded.wayPoints
        if WayPointExists(wayPoint)
            push!(wayPoints, traversablePaths_Dict[wayPoint])
        end
    end

    startTile::MapTile = wayPoints[1]
    endTile::MapTile = wayPoints[end]

    mapBordersMutable::Array{MutableMapTile} = GenerateMapBorders(Int32(1), loaded.xMax, Int32(1), loaded.yMax)
    mapBorders::Array{MapTile} = []
    for mut in mapBordersMutable
        push!(mapBorders, MakeImmutable(mut))
    end
    return ComputedMaze(
        startTile,
        endTile,
        mapBorders,
        allMapTiles,
        wayPoints)
end


function GenerateMapBorders(xMin::Int32, xMax::Int32, yMin::Int32, yMax::Int32)
    mapBorders = MutableMapTile[]
    for x::Int32 in xMin-1:xMax+1
        push!(mapBorders, CreateMapBorder(x, Int32(yMin - 1)))
        push!(mapBorders, CreateMapBorder(x, Int32(yMax + 1)))
    end
    for y::Int32 in yMin:yMax
        push!(mapBorders, CreateMapBorder(Int32(xMin - 1), y))
        push!(mapBorders, CreateMapBorder(Int32(xMax + 1), y))
    end
    return mapBorders
end

