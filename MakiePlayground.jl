using GLMakie
using Colors
using Makie.Colors
using Random
using Dates

include("MakieRenderer.jl")

function ShowMap()
    fig = Figure()
    axis = Axis(fig[1, 1])

    color = :black

    SquareAtPoint(axis, (0, 0), color=color)
    SquareAtPoint(axis, (1, 1), color=color)
    SquareAtPoint(axis, (2, 2), color=color)
    SquareAtPoint(axis, (3, 1), color=color)
    SquareAtPoint(axis, (4, 0), color=color)
    SquareAtPoint(axis, (-4, 6), color=color)

    # colsize!(fig.layout, 1, Aspect(1, 1.0))
    axis.aspect = DataAspect() # Makes the y and x axis scaled equally.
    hidedecorations!(axis) # Removes the x and y axis numbers. 

    resize_to_layout!(fig)
    display(fig)
    return fig
end

function ShowSimplePlot()
    seconds = 0:0.1:2
    data = [8.2, 8.4, 6.3, 9.5, 9.1, 10.5, 8.6, 8.2, 10.5, 8.5, 7.2,
        8.8, 9.7, 10.8, 12.5, 11.6, 12.1, 12.1, 15.1, 14.7, 13.1]

    dataExponential = exp.(data)

    #=
    multi line comment looks like this
    =#

    figure = Figure(size=(1300, 600)) # resolution=deprecated, size is the new thing.
    set_theme!()
    # set_theme!(backgroundcolor=("green", 0.1))


    # leftAxis = Axis(
    #     figure[1, 1],
    #     aspect=0.3,
    #     title="Lefty Lefty (normal mode)",
    #     xlabel="Seconds",
    #     ylabel="DataPower"
    # )
    # leftAxis.backgroundcolor=("blue", 0.2)


    rightAxis = Axis(
        figure[1, 1],
        # aspect=0.5,
        title="Righty Righty (lowkey exponential)",
        xlabel="Seconds",
        ylabel="DataPower",
        backgroundcolor=("red", 0.2)
    )


    # lines!(leftAxis, seconds, data, color=:tomato, linestyle=:dash, label="LhsLine Label Bro")
    # scatter!(leftAxis, seconds, data .+ 0.2, color=:green, label="LhsScatter Label Bro")

    lines!(rightAxis, seconds, dataExponential, label="rhsLine hawk tuah")
    scatter!(rightAxis, seconds, dataExponential .+ 0.2, label="rhsScatter hawk tuah")

    # Box(figure[1, 1], color=(:red, 0.4), strokewidth=2)
    # Box(figure[1, 1], color=(:blue, 0.4), strokewidth=2)

    Colorbar(figure[1, 2])

    #= 
    Set the size of the figure's grid columnms, rather than the aspect 
    of the figures that live inside, to control the whitespace properly.
    =#
    colsize!(figure.layout, 1, Aspect(1, 1.0))

    # axislegend(leftAxis, position=:rt)
    axislegend(rightAxis, position=:lb)

    resize_to_layout!(figure)
    # resize!(figure, (600, 1200))
    display(figure)
    return figure
end


function GenerateRandomPointsForMap(xMin, xMax, yMin, yMax; seed::Int64=-1)::Array{Tuple{Int,Int},1}
    if seed < 0
        seed = Int(round(time()))
        println("Generated a seed based on time")
    end

    Random.seed!(seed)

    println("Generating random points with seed $seed")

    totalSquares = xMax * yMax
    numberOfPoints = rand(1:(Int(totalSquares * 0.5)))
    println("Placing $numberOfPoints points")

    points = Tuple{Int,Int}[]

    for i in 1:numberOfPoints
        while true
            candidatePoint = (rand(xMin:xMax), rand(yMin:yMax))
            if !(candidatePoint in points)
                push!(points, candidatePoint)
                break
            end
        end
    end

    println("Generated the following points: ")
    display(points)
    return points
end


function ShowGridOfGrids()
    gridFigure = Figure()

    gridSize = 100

    for i in 1:5, j in 1:5
        axis = Axis(gridFigure[i, j], width=gridSize, height=gridSize)

        if i % 2 == 0 && j % 2 == 0

            axis.backgroundcolor = (:red, 0.2)
        end
    end


    resize_to_layout!(gridFigure)
    display(gridFigure)
    return gridFigure
end


function ProomptedGrid()
    fig = Figure()
    ax = Axis(fig[1, 1])

    for i in 1:2, j in 1:2
        x = [i - 1, i, i, i - 1]
        y = [j - 1, j - 1, j, j]
        color = iseven(i + j) ? :black : :white
        poly!(ax, Point2f.(x, y), color=color)
    end

    limits!(ax, 0, 2, 0, 2)
    ax.aspect = DataAspect()
    display(fig)
end