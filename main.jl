using GLMakie
using Colors
using Makie.Colors
using Random
using Dates

include("Utilities.jl")
include("MazeGenerator.jl")
include("MakiePlayground.jl")
include("MakieRenderer.jl")
include("AStar_SingleThreaded.jl")














function ShowBigMap()


    # TODO: Replace this random gen with prims algorithm

    points = Tuple{Int,Int}[]
    # for i in 1:100
    #     print("Generating maze with i == $i")
    #     points = PrimsMazeGenerator(xMin, xMax, yMin, yMax, seed=i)
    # end

    PunctureHoles!(points)

    # points = Tuple{Int, Int}[]
    # points = GenerateRandomPointsForMap(xMin, xMax, yMin, yMax, seed=-1)

    numberOfPoints = length(points)
    shouldDrawText = numberOfPoints < 5

    for point in points
        SquareAtPoint(axis, point, shouldDrawText=shouldDrawText)
    end

    println("Placed squares at $(length(points)) points. Going to display them now.")

    borderColor = :green

    # Drawing a border around
    for verti in (yMin-1):(yMax+1)
        SquareAtPoint(axis, (xMin - 1, verti), color=borderColor, shouldDrawText=false)
        SquareAtPoint(axis, (xMax + 1, verti), color=borderColor, shouldDrawText=false)
    end
    for hori in (xMin-1):(xMax+1)
        SquareAtPoint(axis, (hori, yMin - 1), color=borderColor, shouldDrawText=false)
        SquareAtPoint(axis, (hori, yMax + 1), color=borderColor, shouldDrawText=false)
    end

    axis.aspect = DataAspect() # Makes the y and x axis scaled equally.
    hidedecorations!(axis) # Removes the x and y axis numbers. 

    resize_to_layout!(fig)
    display(fig)
    return fig

end


function ShowMaze(xMin, xMax, yMin, yMax, walls::Array{Tuple{Int,Int}}, shortestPath::Array{Tuple{Int, Int}})
    fig = Figure()
    axis = Axis(fig[1, 1])

    for wall in walls
        if !(wall in shortestPath)
            SquareAtPoint(axis, wall, shouldDrawText=false)
        end
    end

    for path in shortestPath
        SquareAtPoint(axis, path, color=:green, shouldDrawText=false)
    end

    borderColor = :green

    # # Drawing a border around
    # for verti in (yMin-1):(yMax+1)
    #     SquareAtPoint(axis, (xMin - 1, verti), color=borderColor, shouldDrawText=false)
    #     SquareAtPoint(axis, (xMax + 1, verti), color=borderColor, shouldDrawText=false)
    # end
    # for hori in (xMin-1):(xMax+1)
    #     SquareAtPoint(axis, (hori, yMin - 1), color=borderColor, shouldDrawText=false)
    #     SquareAtPoint(axis, (hori, yMax + 1), color=borderColor, shouldDrawText=false)
    # end

    axis.aspect = DataAspect() # Makes the y and x axis scaled equally.
    hidedecorations!(axis) # Removes the x and y axis numbers. 

    resize_to_layout!(fig)
    display(fig)
    return fig
end

function CreateMaze()
end

function main()
    println("Entered main()")

    xMin = 0
    xMax = 10
    yMin = 0
    yMax = 10
    seed = 5
    walls = PrimsMazeGenerator(xMin, xMax, yMin, yMax, seed=seed)

    # TODO: Modify the maze to use the maptiles too
    wallMapTiles = [MapTile(x, y) for (x, y) in walls]
    startTile = MapTile(xMin, yMin)
    endTile = MapTile(xMax, yMax)

    println(typeof(walls))
    st_shortestPath = st_AStar(wallMapTiles, startTile, endTile)

    mazeImage = ShowMaze(xMin, xMax, yMin, yMax, walls, st_shortestPath)
    save("mazeImage.png", mazeImage)



    # fig = Figure()
    println("Done with main().")
end





main()