
using GLMakie
using Colors
using Makie.Colors
using Random
using Dates

include("Utilities.jl")

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