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


function AddEnvironment!(walls::Array{MapTile})
    for wall in walls
        diceroll = rand(1:100)
        if diceroll < 5
            wall.costToReach = 3
        elseif diceroll < 15
            wall.costToReach = 2
        else
            wall.costToReach = 1
        end
    end
end


function ShowMaze(xMin, xMax, yMin, yMax, walls::Array{Tuple{Int,Int}}, shortestPath::Array{Tuple{Int,Int}})
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




function FindExistingMapTile(x, y, existingTiles::Array{MapTile})
    for existingTile in existingTiles
        if existingTile.x == x && existingTile.y == y
            return existingTile
        end
    end
    error("Failed to find the existing tile with x $x and y $y")
end



function main()
    println("Entered main()")
    seed = 5
    if seed < 0
        seed = Int(round(time()))
        println("Generated a seed based on time")
    end
    Random.seed!(seed)

    xMin = 0
    xMax = 10
    yMin = 0
    yMax = 10
    walls = PrimsMazeGenerator(xMin, xMax, yMin, yMax)

    # TODO: Modify the maze to use the maptiles too, maybe? it would just be a cleanup though.
    wallMapTiles = [MapTile(x, y) for (x, y) in walls]
    AddEnvironment!(wallMapTiles)

    startTile = FindExistingMapTile(xMin, yMin, )
    endTile = FindExistingMapTile(xMax, yMax)

    st_shortestPath = Tuple{Int64,Int64}[]
    st_shortestPath = st_AStar(wallMapTiles, startTile, endTile)

    mazeImage = ShowMaze(xMin, xMax, yMin, yMax, walls, st_shortestPath)
    save("mazeImage.png", mazeImage)



    # fig = Figure()
    println("Done with main().")
end





main()