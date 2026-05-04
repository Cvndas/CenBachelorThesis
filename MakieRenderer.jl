
using GLMakie
using Colors
using Makie.Colors
using Random
using Dates
using GeometryBasics

using .CenAstar


function DrawSquares(axis::Axis, coordinates::Array{Tuple{Int32,Int32}}, color)

    squaresAsPolys = []
    for coord in coordinates
        x = coord[1]
        y = coord[2]
        bottomLeft = (x, y)
        bottomRight = (x + 1, y)
        topRight = (x + 1, y + 1)
        topLeft = (x, y + 1)
        poly = Polygon(Point2f[bottomLeft, bottomRight, topRight, topLeft])
        push!(squaresAsPolys, poly)
    end

    poly!(axis, squaresAsPolys, color=color)
end

function CreateOutline(coord::Tuple{Int32,Int32}, thickness)
    outlineAsPolys = []
    x = coord[1]
    y = coord[2]

    # Bottom row poly
    bottomRow_left = (x, y)
    bottomRow_right = (x + 1, y)
    bottomRow_topLeft = (x, y + thickness)
    bottomRow_topRight = (x + 1, y + thickness)
    bottomRowPoly = Polygon(Point2f[bottomRow_left, bottomRow_right, bottomRow_topRight, bottomRow_topLeft])

    # Top row poly
    topRow_left = (x, y + 1)
    topRow_right = (x + 1, y + 1)
    topRow_bottomLeft = (x, y + 1 - thickness)
    topRow_bottomRight = (x + 1, y + 1 - thickness)
    topRowPoly = Polygon(Point2f[topRow_bottomLeft, topRow_bottomRight, topRow_right, topRow_left])

    # Left Column poly
    leftCol_bottomLeft = (x, y)
    leftCol_bottomRight = (x + thickness, y)
    leftCol_topLeft = (x, y + 1)
    leftCol_topRight = (x + thickness, y + 1)
    leftColPoly = Polygon(Point2f[leftCol_bottomLeft, leftCol_bottomRight, leftCol_topRight, leftCol_topLeft])

    # Right Column poly
    rightCol_bottomRight = (x + 1, y)
    rightCol_topRight = (x + 1, y + 1)
    rightCol_topLeft = (x + 1 - thickness, y + 1)
    rightCol_bottomLeft = (x + 1 - thickness, y)
    rightColPoly = Polygon(Point2f[rightCol_bottomLeft, rightCol_bottomRight, rightCol_topRight, rightCol_topLeft])


    push!(outlineAsPolys, bottomRowPoly)
    push!(outlineAsPolys, topRowPoly)
    push!(outlineAsPolys, leftColPoly)
    push!(outlineAsPolys, rightColPoly)

    return outlineAsPolys
end




function DrawOutline(axis::Axis, coord::Tuple{Int32,Int32}, color, thickness; text="")
    asPoly = CreateOutline(coord, thickness)
    poly!(axis, asPoly, color=color)


    if text != ""
        x = coord[1]
        y = coord[2]
        text!(axis, text, position=(x + 0.2, y + 0.3))
    end
end




function DrawOutlines(axis::Axis, coordinates::Array{Tuple{Int32,Int32}}, color, thickness)
    outlinesAsPolys::Vector{Tuple{Int32,Int32}} = []
    for coord in coordinates
        vcat(outlinesAsPolys, CreateOutline(coord, thickness))
    end
    poly!(axis, outlinesAsPolys, color=color)
end





function SquareAtPoint(axis::Axis, coord::Tuple{Int,Int}; color=:black, shouldDrawText=true)
    SquareAtPoint(axis, coord[1], coord[2], color=color, shouldDrawText=shouldDrawText)
end





function SquareAtPoint(axis::Axis, x::Int, y::Int; color=:black, shouldDrawText=true)
    polygon_bottomLeft = (x, y)
    polygon_bottomRight = (x + 1, y)
    polygon_topRight = (x + 1, y + 1)
    polygon_topLeft = (x, y + 1)

    textX = x + 0.23
    textY = y + 0.38
    coordinateText = "($x, $y)"
    textColor = InvertedColor(to_color(color))

    poly!(axis, Point2f[polygon_bottomLeft, polygon_bottomRight, polygon_topRight, polygon_topLeft], color=color)
    if shouldDrawText
        text!(axis, textX, textY, text=coordinateText, color=textColor)
    end
end


function ShowMaze(solvedMaze::SolvedMaze)
    fig = Figure(; size=(1600, 900))
    axis = Axis(fig[1, 1])

    # Creating batches for terrain
    dirtPath = MapTile[]
    waterPath = MapTile[]
    boostpadPath = MapTile[]

    for tile::MapTile in solvedMaze.pathMapTiles
        if tile.costToReach == PATHCOST_Mud
            push!(dirtPath, tile)
        elseif tile.costToReach == PATHCOST_Water
            push!(waterPath, tile)
        elseif tile.costToReach == PATHCOST_BoostPad
            push!(boostpadPath, tile)
        end
    end

    if !isempty(dirtPath)
        dirtCoords = [(tile.x, tile.y) for tile in dirtPath]
        DrawSquares(axis, dirtCoords, PATHCOLOR_Mud)
    end

    if !isempty(waterPath)
        waterCoords = [(tile.x, tile.y) for tile in waterPath]
        DrawSquares(axis, waterCoords, PATHCOLOR_Water)
    end

    if !isempty(boostpadPath)
        boostpadCoords = [(tile.x, tile.y) for tile in boostpadPath]
        DrawSquares(axis, boostpadCoords, PATHCOLOR_BoostPad)
    end

    if !isempty(solvedMaze.wallMapTiles)
        walls = [(tile.x, tile.y) for tile in solvedMaze.wallMapTiles]
        # @assert solvedMaze.wallMapTiles[1].color == :black "Wall color was $(solvedMaze.wallMapTiles[1].color)"
        DrawSquares(axis, walls, PATHCOLOR_Wall)
    end

    if !isempty(solvedMaze.mapBorderTiles)
        borders = [(tile.x, tile.y) for tile in solvedMaze.mapBorderTiles]
        DrawSquares(axis, borders, PATHCOLOR_MapBorder)
    end

    if !isempty(solvedMaze.shortestPathTiles)
        spTiles = [(tile.x, tile.y) for tile in solvedMaze.shortestPathTiles]
        DrawSquares(axis, spTiles, PATHCOLOR_Traversed)
    end

    if !isempty(solvedMaze.wayPoints)
        wayPoints = [(tile.x, tile.y) for tile in solvedMaze.wayPoints]
        DrawSquares(axis, wayPoints, PATHCOLOR_WayPoint)
    end

    axis.aspect = DataAspect() # Makes the y and x axis scaled equally.
    hidedecorations!(axis) # Removes the x and y axis numbers. 

    resize_to_layout!(fig)
    display(fig)
    return fig
end