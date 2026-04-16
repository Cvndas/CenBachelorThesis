
using GLMakie
using Colors
using Makie.Colors
using Random
using Dates

function InvertedColor(color)
    asRgba = RGBAf(color)
    return RGBAf(1 - asRgba.r, 1 - asRgba.g, 1 - asRgba.b, asRgba.alpha)
end




# This function assumes that the play space is enclosed by walls. Therefore, this should only be called
# on mazes that are already complete
function MapTile_GetNeighbors(mapTile::MapTile, walls::Array{MapTile})::Array{MapTile}
    neighbors = [MapTile(mapTile.x, mapTile.y + 1),
        MapTile(mapTile.x + 1, mapTile.y),
        MapTile(mapTile.x, mapTile.y - 1),
        MapTile(mapTile.x - 1, mapTile.y)]
    filter!(x -> !(x in walls), neighbors)
    return neighbors
end



struct MapTile
    x::Int
    y::Int
    costToReach::Int

    function MapTile(x::Int, y::Int; costToReach=1)
        new(x, y, costToReach)
    end
end


function NotImplemented()
    error("Not Implemented")
end