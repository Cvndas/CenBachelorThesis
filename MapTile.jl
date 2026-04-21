
mutable struct MapTile
    x::Int32
    y::Int32
    costToReach::Int16

    function MapTile(x::Int, y::Int; costToReach=1)
        new(x, y, costToReach)
    end
end