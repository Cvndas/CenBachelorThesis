using GLMakie
using Serialization



mutable struct Cursor
    x::Int32
    y::Int32
end

function show(io::IO, cursor::Cursor)
    print(io, "$(cursor.x), $(cursor.y)")
end

mutable struct MazeBuildState
    xMax::Int32
    yMax::Int32
    fig
    mazeAxis
    cursor::Cursor
    mapTiles::Matrix{MutableMapTile}

    # Set to (-1, -1) if it doesn't exist
    wayPoints::Vector{Tuple{Int32,Int32}}
    done::Bool
    # TODO: Add waypoints too
    # TODO: Add start and end points too 
end



s::Union{MazeBuildState,Nothing} = nothing
gUndoState::Vector{MazeBuildState} = []
gUndoDepth::Int = 0
gMapName::String = ""

function WayPointExists(wayPoint::Tuple{Int32,Int32})
    return wayPoint[1] >= 1 && wayPoint[2] >= 1
end

function RenderMapBuild()
    global s

    start = time()

    axis = s.mazeAxis
    empty!(axis)

    dirtPath = MutableMapTile[]
    waterPath = MutableMapTile[]
    boostpadPath = MutableMapTile[]
    walls = MutableMapTile[]
    borders = Tuple{Int32,Int32}[]

    for borderX in 0:s.xMax+1
        push!(borders, (Int32(borderX), Int32(0)))
        push!(borders, (Int32(borderX), Int32(s.yMax + 1)))
    end
    for borderY in 0:s.yMax+1
        push!(borders, (Int32(0), Int32(borderY)))
        push!(borders, (Int32(s.xMax + 1), Int32(borderY)))
    end

    for tile::MutableMapTile in s.mapTiles
        if tile.costToReach == PATHCOST_Mud
            push!(dirtPath, tile)
        elseif tile.costToReach == PATHCOST_Water
            push!(waterPath, tile)
        elseif tile.costToReach == PATHCOST_BoostPad
            push!(boostpadPath, tile)
        elseif tile.costToReach == PATHCOST_Wall
            push!(walls, tile)
        end
    end

    dirtCoords = [(tile.x, tile.y) for tile in dirtPath]
    waterCoords = [(tile.x, tile.y) for tile in waterPath]
    boostpadCoords = [(tile.x, tile.y) for tile in boostpadPath]
    wa = [(tile.x, tile.y) for tile in walls]

    # println("Sorting the maptiles took $(time() - start) seconds")

    if !isempty(dirtPath)
        DrawSquares(axis, dirtCoords, PATHCOLOR_Mud)
    end
    if !isempty(waterPath)
        DrawSquares(axis, waterCoords, PATHCOLOR_Water)
    end
    if !isempty(boostpadPath)
        DrawSquares(axis, boostpadCoords, PATHCOLOR_BoostPad)
    end
    if !isempty(walls)
        DrawSquares(axis, wa, PATHCOLOR_Wall)
    end

    WayPointExists = (wayPoint::Tuple{Int32,Int32}) -> wayPoint[1] >= 1 && wayPoint[2] >= 1
    for (i, wayPoint) in enumerate(s.wayPoints)
        if WayPointExists(wayPoint)
            DrawOutline(axis, wayPoint, :purple, 0.2, text="w$i")
        end
    end

    DrawSquares(axis, borders, PATHCOLOR_MapBorder)
    DrawOutline(axis, (s.cursor.x, s.cursor.y), :green, 0.1)
    # DrawSquares(axis, [(s.cursor.x, s.cursor.y)], :green)


    resize_to_layout!(s.fig)
    display(s.fig)
    println("Drawing the maptiles took $(time() - start) seconds")
end




# Long func, but it works. Was a pain to write.
function ResizeMaze(resizeSymbol)
    global s
    # Adding a row of empty at the top.
    if resizeSymbol == :IncreaseTop
        s.yMax += 1
        newMap = Matrix{MutableMapTile}(undef, s.xMax, s.yMax)

        for i in 1:s.xMax
            for j in 1:s.yMax-1
                newMap[i, j] = s.mapTiles[i, j]
            end
        end

        for x in 1:s.xMax
            newMap[x, s.yMax] = CreateDefault(Int32(x), Int32(s.yMax))
        end

        s.mapTiles = newMap

    elseif resizeSymbol == :DecreaseTop
        if s.yMax == 1
            return
        end

        s.yMax -= 1
        newMap = Matrix{MutableMapTile}(undef, s.xMax, s.yMax)
        for i in 1:s.xMax
            for j in 1:s.yMax
                newMap[i, j] = s.mapTiles[i, j]
            end
        end
        s.mapTiles = newMap


    elseif resizeSymbol == :IncreaseRight
        s.xMax += 1
        newMap = Matrix{MutableMapTile}(undef, s.xMax, s.yMax)

        for i in 1:s.xMax-1
            for j in 1:s.yMax
                newMap[i, j] = s.mapTiles[i, j]
            end
        end

        for y in 1:s.yMax
            newMap[s.xMax, y] = CreateDefault(Int32(s.xMax), Int32(y))
        end

        s.mapTiles = newMap

    elseif resizeSymbol == :DecreaseRight
        if s.xMax == 1
            return
        end

        s.xMax -= 1
        newMap = Matrix{MutableMapTile}(undef, s.xMax, s.yMax)

        for i in 1:s.xMax
            for j in 1:s.yMax
                newMap[i, j] = s.mapTiles[i, j]
            end
        end
        s.mapTiles = newMap

    elseif resizeSymbol == :IncreaseBottom
        s.yMax += 1

        newMap = Matrix{MutableMapTile}(undef, s.xMax, s.yMax)

        for i in 1:s.xMax
            for j in 1:s.yMax-1
                newMap[i, j+1] = s.mapTiles[i, j]
            end
        end

        for x in 1:s.xMax
            newMap[x, 1] = CreateDefault(Int32(x), Int32(0))
        end

        # Shifting everything up
        for tile::MutableMapTile in newMap
            tile.y += 1
        end
        s.cursor.y += 1

        s.mapTiles = newMap

    elseif resizeSymbol == :DecreaseBottom
        if s.yMax == 1
            return
        end

        s.yMax -= 1
        newMap = Matrix{MutableMapTile}(undef, s.xMax, s.yMax)

        for i in 1:s.xMax
            for j in 1:s.yMax
                newMap[i, j] = s.mapTiles[i, j+1]
            end
        end

        # Shifting everything down
        for tile::MutableMapTile in newMap
            tile.y -= 1
        end

        s.cursor.y += 1
        s.mapTiles = newMap

    elseif resizeSymbol == :IncreaseLeft
        s.xMax += 1
        newMap = Matrix{MutableMapTile}(undef, s.xMax, s.yMax)

        for i in 1:s.xMax-1
            for j in 1:s.yMax
                newMap[i+1, j] = s.mapTiles[i, j]
            end
        end
        for y in 1:s.yMax
            newMap[1, y] = CreateDefault(Int32(0), Int32(y))
        end
        # Shifting everything right
        for tile::MutableMapTile in newMap
            tile.x += 1
        end
        s.cursor.x += 1
        s.mapTiles = newMap


    elseif resizeSymbol == :DecreaseLeft
        if s.xMax == 1
            return
        end

        s.xMax -= 1
        newMap = Matrix{MutableMapTile}(undef, s.xMax, s.yMax)
        for i in 1:s.xMax
            for j in 1:s.yMax
                newMap[i, j] = s.mapTiles[i+1, j]
            end
        end
        # Shifting everything left
        for tile::MutableMapTile in newMap
            tile.x -= 1
        end
        s.cursor.x -= 1
        s.mapTiles = newMap


    else
        error("didn't map symbol $resizeSymbol")
    end

    if s.cursor.x > s.xMax
        s.cursor.x = s.xMax
    elseif s.cursor.x < 1
        s.cursor.x = 1
    end

    if s.cursor.y > s.yMax
        s.cursor.y = s.yMax
    elseif s.cursor.y < 1
        s.cursor.y = 1
    end
end







function HandleKeyboardInput(k::Makie.Keyboard.Button)
    global s
    global gUndoDepth
    global gUndoState
    global gMapNameProvided


    saveState::Bool = false
    # println("Key was hit! $k")
    if k == Keyboard.up
        s.cursor.y += 1
        if s.cursor.y > s.yMax
            s.cursor.y = s.yMax
        end
        # println("The cursor is on $(s.cursor)")
    elseif k == Keyboard.down
        s.cursor.y -= 1
        if s.cursor.y < 1
            s.cursor.y = 1
        end
        # println("The cursor is on $(s.cursor)")

    elseif k == Keyboard.left
        s.cursor.x -= 1
        if s.cursor.x < 1
            s.cursor.x = 1
        end
        # println("The cursor is on $(s.cursor)")

    elseif k == Keyboard.right
        s.cursor.x += 1
        if s.cursor.x > s.xMax
            s.cursor.x = s.xMax
        end
        # println("The cursor is on $(s.cursor)")

    elseif k == Keyboard.l
        # println("Increasing the map size on the right")
        ResizeMaze(:IncreaseRight)
        saveState = true

    elseif k == Keyboard.k
        # println("Decreasing the map size on the right")
        ResizeMaze(:DecreaseRight)
        saveState = true

    elseif k == Keyboard.j
        # println("Increasing the map size on the right")
        ResizeMaze(:IncreaseLeft)
        saveState = true
    elseif k == Keyboard.h
        # println("Decreasing the map size on the right")
        ResizeMaze(:DecreaseLeft)
        saveState = true

    elseif k == Keyboard.i
        # println("Increasing the map size on the top")
        ResizeMaze(:IncreaseTop)
        saveState = true
    elseif k == Keyboard.u
        # println("Decreasing the map size on the top")
        ResizeMaze(:DecreaseTop)
        saveState = true

    elseif k == Keyboard.m
        # println("Increasing the map size on the bottom")
        ResizeMaze(:IncreaseBottom)
        saveState = true

    elseif k == Keyboard.n
        # println("Decreasing the map size on the bottom")
        ResizeMaze(:DecreaseBottom)
        saveState = true

    elseif k == Keyboard.g
        # println("Placing a wall on tile $(s.mapTiles[s.cursor.x, s.cursor.y])")
        s.mapTiles[s.cursor.x, s.cursor.y] = CreateWall(s.cursor.x, s.cursor.y)
        # saveState = true

    elseif k == Keyboard.a
        # println("Placing water on tile $(s.mapTiles[s.cursor.x, s.cursor.y])")
        ConvertToWater!(s.mapTiles[s.cursor.x, s.cursor.y])
        # saveState = true

    elseif k == Keyboard.s
        # println("Placing boostpad on tile $(s.mapTiles[s.cursor.x, s.cursor.y])")
        ConvertToBoostPad!(s.mapTiles[s.cursor.x, s.cursor.y])
        # saveState = true

    elseif k == Keyboard.d
        # println("Placing mud on tile $(s.mapTiles[s.cursor.x, s.cursor.y])")
        ConvertToMud!(s.mapTiles[s.cursor.x, s.cursor.y])
        # saveState = true

    elseif k == Keyboard.f
        # println("Placing empty on tile $(s.mapTiles[s.cursor.x, s.cursor.y])")
        s.mapTiles[s.cursor.x, s.cursor.y] = CreateDefault(s.cursor.x, s.cursor.y)
        # saveState = true

    elseif k == Keyboard.p
        for mapTile::MutableMapTile in s.mapTiles
            if mapTile.costToReach == PATHCOST_Wall
                mapTile.costToReach = PATHCOST_Default
            elseif mapTile.costToReach == PATHCOST_Default
                mapTile.costToReach = PATHCOST_Wall
            end
        end
        # saveState = true

    elseif k == Keyboard._1
        s.wayPoints[1] = (s.cursor.x, s.cursor.y)
    elseif k == Keyboard._2
        s.wayPoints[2] = (s.cursor.x, s.cursor.y)
    elseif k == Keyboard._3
        s.wayPoints[3] = (s.cursor.x, s.cursor.y)
    elseif k == Keyboard._4
        s.wayPoints[4] = (s.cursor.x, s.cursor.y)
    elseif k == Keyboard._5
        s.wayPoints[5] = (s.cursor.x, s.cursor.y)
    elseif k == Keyboard._6
        s.wayPoints[6] = (s.cursor.x, s.cursor.y)
    elseif k == Keyboard._7
        s.wayPoints[7] = (s.cursor.x, s.cursor.y)
    elseif k == Keyboard._8
        s.wayPoints[8] = (s.cursor.x, s.cursor.y)
    elseif k == Keyboard._9
        s.wayPoints[9] = (s.cursor.x, s.cursor.y)
    elseif k == Keyboard._0
        for (i, wayPoint) in enumerate(s.wayPoints)
            if wayPoint[1] == s.cursor.x && wayPoint[2] == s.cursor.y
                s.wayPoints[i] = (Int32(-1), Int32(-1))
            end
        end

    elseif k == Keyboard.q
        # SaveMap()
        println("Exiting!")
        s.done = true

    elseif k == Keyboard.w
        SaveMap()

    elseif k == Keyboard.z
        println("Doing an Undo")
        Undo()
    elseif k == Keyboard.y
        println("Doing a redo")
        Redo()
    end

    # if currentMoveWasQuit
    #     s.previousMoveWasQuit = true
    # else
    #     s.previousMoveWasQuit = false
    # end

    if saveState
        # If adding a move and not at the undo tail, discard tail first
        if gUndoDepth != length(gUndoState)
            gUndoState = gUndoState[1:gUndoDepth]
            # println("A move was done when not at tail of undo, so old undo tail was dropped")
        end

        stateCopy = MazeBuildState(s.xMax, s.yMax, s.fig, s.mazeAxis, deepcopy(s.cursor), deepcopy(s.mapTiles), deepcopy(s.wayPoints), s.done)
        gUndoDepth += 1

        push!(gUndoState, stateCopy)
        # s = stateCopy

        # println("After doing move, undo depth is $(gUndoDepth)")

    end
end

function Redo()
    global gUndoDepth
    global gUndoState
    global s
    max = length(gUndoState)
    if max > gUndoDepth
        gUndoDepth += 1
    end

    s = gUndoState[gUndoDepth]
    s = MazeBuildState(s.xMax, s.yMax, s.fig, s.mazeAxis, deepcopy(s.cursor), deepcopy(s.mapTiles), deepcopy(s.wayPoints), s.done)
end

function Undo()
    global gUndoDepth
    global gUndoState
    global s
    # println("Old undo depth: $(gUndoDepth)")
    gUndoDepth -= 1
    if gUndoDepth <= 1
        gUndoDepth = 1
    end

    s = gUndoState[gUndoDepth]
    s = MazeBuildState(s.xMax, s.yMax, s.fig, s.mazeAxis, deepcopy(s.cursor), deepcopy(s.mapTiles), deepcopy(s.wayPoints), s.done)
    # println("New undo depth: $(gUndoDepth)")
end




function SaveMap()
    global gMapName
    global s

    if gMapName == ""
        println("Please provide a map name, or input t to discard")
        input = readline()
        if input == "t"
            return
        else
            gMapName = input
        end
    end

    saveData = SavedMaze(s.xMax, s.yMax, deepcopy(s.mapTiles), deepcopy(s.wayPoints))

    @assert gMapName != "" "Map name was not set in SaveMap()"
    dir = "Custom Maps"
    mkpath("Custom Maps")
    path = joinpath(dir, gMapName * ".map")

    open(path, "w") do file
        serialize(file, saveData)
    end

    println("Saved gMapName to $path")
end

function LoadMapToEdit(mapName::String)
    dir = "Custom Maps"
    path = joinpath(dir, mapName * ".map")

    loaded::SavedMaze = open(path, "r") do file
        deserialize(file)
    end
    return loaded
end

function UpdateOldMaps(oldMap::SavedMaze)
    for mapTile in oldMap.mapTiles
        if mapTile.costToReach == Int32(20)
            mapTile.costToReach = PATHCOST_Wall
        end
    end
end

function RunMapBuilder(mapToEdit::String)
    global s
    global gUndoDepth
    global gUndoState
    global gMapName
    println("Welcome to the map builder!")
    println("Controls: \n",
        "i & u: resize top of map\n",
        "n & m: resize bottom of map\n",
        "k & l: resize right of map\n",
        "h & l: resize left of map\n",
        "1 - 10: Waypoints, 0 to clear waypoint on cursor\n",
        "a: water, s: boostpad, d: dirt, f: default, g: wall\n",
        "p: Flip Default and Wall\n",
        "z: undo, y: redo\n",
        "q: quit\n"
    )

    fig = Figure(; size=(1600, 900))
    axis = Axis(fig[1, 1])

    # textAxis = Axis(fig[1, 2])
    # text!(textAxis, "Map Builder")

    hidedecorations!(axis)
    # hidedecorations!(textAxis)
    axis.aspect = DataAspect()

    # Starting fresh
    if mapToEdit == ""
        mapTiles = Matrix{MutableMapTile}(undef, 1, 1)
        mapTiles[1, 1] = CreateDefault(Int32(1), Int32(1))

        wayPoints::Vector{Tuple{Int32,Int32}} = []
        for _ in 1:9
            push!(wayPoints, (Int32(-1), Int32(-1)))
        end

        s = MazeBuildState(Int32(1), Int32(1), fig, axis, Cursor(1, 1), mapTiles, wayPoints, false)

        # Editing an existing map
    else
        loaded::SavedMaze = LoadMapToEdit(mapToEdit)
        UpdateOldMaps(loaded)
        s = MazeBuildState(loaded.xMax, loaded.yMax, fig, axis, Cursor(1, 1), loaded.mapTiles, loaded.wayPoints, false)
    end

    stateCopy = MazeBuildState(s.xMax, s.yMax, s.fig, s.mazeAxis, deepcopy(s.cursor), deepcopy(s.mapTiles), deepcopy(s.wayPoints), s.done)
    push!(gUndoState, stateCopy)
    gUndoDepth = 1

    # Handling keyboard events.
    # https://docs.makie.org/dev/explanations/events
    # scene = Scene(camera=campixel!)
    RenderMapBuild()


    on(events(fig).keyboardbutton) do event
        keyHit = event.action == Keyboard.press
        keyHit || return
        HandleKeyboardInput(event.key)
        RenderMapBuild()

        while gUndoDepth > 50
            popfirst!(gUndoState)

            gUndoDepth -= 1
        end
    end
    # display(scene)
    display(fig)

    # TODO: Waypoints and serialization.

    while s.done == false
        sleep(0.5)
    end

    SaveMap()


    println("Broke out of the sleeping loop")


    GLMakie.closeall()
end