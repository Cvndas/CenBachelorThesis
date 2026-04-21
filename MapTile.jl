
mutable struct MapTile
    x::Int
    y::Int
    costToReach::Int
    color
    # neighbors::Array{MapTile}

    function MapTile(x::Int, y::Int; costToReach=1, color=:white)
        new(x, y, costToReach, color)
    end
end