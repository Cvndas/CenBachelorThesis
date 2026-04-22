import Base: show

# isbits() doesn't pass here
mutable struct MutableMapTile
    x::Int32
    y::Int32
    costToReach::Int16

    function MutableMapTile(x::Int32, y::Int32; costToReach=1)
        new(x, y, costToReach)
    end
end

# isbits() does pass 
struct MapTile
    x::Int32
    y::Int32
    costToReach::Int16
    function MapTile(x::Int32, y::Int32; costToReach=1)
        new(x, y, costToReach)
    end
end

function MakeImmutable(mutable::MutableMapTile)::MapTile
    return MapTile(mutable.x, mutable.y, costToReach=mutable.costToReach)
end


# MAkes the maptile printable
function show(io::IO, tile::MapTile)
    print(io, "MapTile($(tile.x), $(tile.y), costToReach=$(tile.costToReach))")
end

struct ComputedMaze
    startTile::MapTile
    endTile::MapTile
    traversablePaths::Array{MapTile}
    mapBorders::Array{MapTile}
    wallMapTiles::Array{MapTile}
    pathMapTiles::Array{MapTile}
    allTiles::Array{MapTile,2}
end