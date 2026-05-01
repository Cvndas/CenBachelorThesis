using GLMakie



mutable struct Cursor
    x::Int32
    y::Int32
end

function show(io::IO, cursor::Cursor)
    print(io, "$(cursor.x), $(cursor.y)")
end

mutable struct MazeBuildState
    xMax
    yMax
    fig
    mazeAxis
    cursor::Cursor
    mapTiles::Matrix{MutableMapTile}
    done::Bool
    # TODO: Add waypoints too
    # TODO: Add start and end points too 
end


s::Union{MazeBuildState,Nothing} = nothing
gUndoState::Vector{MazeBuildState} = []
gUndoDepth::Int = 0


function RenderMapBuild()
    global s
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
    if !isempty(walls)
        wa = [(tile.x, tile.y) for tile in walls]
        DrawSquares(axis, wa, PATHCOLOR_Wall)
    end

    DrawSquares(axis, borders, PATHCOLOR_MapBorder)
    DrawSquares(axis, [(s.cursor.x, s.cursor.y)], :green)

    resize_to_layout!(s.fig)
    display(s.fig)
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


    saveState::Bool = false
    println("Key was hit! $k")
    if k == Keyboard.up
        s.cursor.y += 1
        if s.cursor.y > s.yMax
            s.cursor.y = s.yMax
        end
        println("The cursor is on $(s.cursor)")
    elseif k == Keyboard.down
        s.cursor.y -= 1
        if s.cursor.y < 1
            s.cursor.y = 1
        end
        println("The cursor is on $(s.cursor)")

    elseif k == Keyboard.left
        s.cursor.x -= 1
        if s.cursor.x < 1
            s.cursor.x = 1
        end
        println("The cursor is on $(s.cursor)")

    elseif k == Keyboard.right
        s.cursor.x += 1
        if s.cursor.x > s.xMax
            s.cursor.x = s.xMax
        end
        println("The cursor is on $(s.cursor)")

    elseif k == Keyboard.l
        println("Increasing the map size on the right")
        ResizeMaze(:IncreaseRight)
        saveState = true

    elseif k == Keyboard.k
        println("Decreasing the map size on the right")
        ResizeMaze(:DecreaseRight)
        saveState = true

    elseif k == Keyboard.j
        println("Increasing the map size on the right")
        ResizeMaze(:IncreaseLeft)
        saveState = true
    elseif k == Keyboard.h
        println("Decreasing the map size on the right")
        ResizeMaze(:DecreaseLeft)
        saveState = true

    elseif k == Keyboard.i
        println("Increasing the map size on the top")
        ResizeMaze(:IncreaseTop)
        saveState = true
    elseif k == Keyboard.u
        println("Decreasing the map size on the top")
        ResizeMaze(:DecreaseTop)
        saveState = true

    elseif k == Keyboard.m
        println("Increasing the map size on the bottom")
        ResizeMaze(:IncreaseBottom)
        saveState = true

    elseif k == Keyboard.n
        println("Decreasing the map size on the bottom")
        ResizeMaze(:DecreaseBottom)
        saveState = true

    elseif k == Keyboard.enter
        println("Placing a wall on tile $(s.mapTiles[s.cursor.x, s.cursor.y])")
        s.mapTiles[s.cursor.x, s.cursor.y] = CreateWall(s.cursor.x, s.cursor.y)
        saveState = true

    elseif k == Keyboard.a
        println("Placing water on tile $(s.mapTiles[s.cursor.x, s.cursor.y])")
        ConvertToWater!(s.mapTiles[s.cursor.x, s.cursor.y])
        saveState = true

    elseif k == Keyboard.s
        println("Placing boostpad on tile $(s.mapTiles[s.cursor.x, s.cursor.y])")
        ConvertToBoostPad!(s.mapTiles[s.cursor.x, s.cursor.y])
        saveState = true

    elseif k == Keyboard.d
        println("Placing mud on tile $(s.mapTiles[s.cursor.x, s.cursor.y])")
        ConvertToMud!(s.mapTiles[s.cursor.x, s.cursor.y])
        saveState = true

    elseif k == Keyboard.f
        println("Placing empty on tile $(s.mapTiles[s.cursor.x, s.cursor.y])")
        s.mapTiles[s.cursor.x, s.cursor.y] = CreateDefault(s.cursor.x, s.cursor.y)
        saveState = true

    elseif k == Keyboard.g
        for mapTile::MutableMapTile in s.mapTiles
            if mapTile.costToReach == PATHCOST_Wall
                mapTile.costToReach = PATHCOST_Default
            elseif mapTile.costToReach == PATHCOST_Default
                mapTile.costToReach = PATHCOST_Wall
            end
        end
        saveState = true

    elseif k == Keyboard.q
        println("Exiting the map builder!")
        s.done = true
        # close(scene)

    elseif k == Keyboard.z
        println("Doing an Undo")
        Undo()
    elseif k == Keyboard.y
        println("Doing a redo")
        Redo()
    end

    if saveState
        # If adding a move and not at the undo tail, discard tail first
        if gUndoDepth != length(gUndoState)
            gUndoState = gUndoState[1:gUndoDepth]
            println("A move was done when not at tail of undo, so old undo tail was dropped")
        end

        stateCopy = MazeBuildState(s.xMax, s.yMax, s.fig, s.mazeAxis, deepcopy(s.cursor), deepcopy(s.mapTiles), s.done)
        gUndoDepth += 1

        push!(gUndoState, stateCopy)
        # s = stateCopy

        println("After doing move, undo depth is $(gUndoDepth)")

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
    s = MazeBuildState(s.xMax, s.yMax, s.fig, s.mazeAxis, deepcopy(s.cursor), deepcopy(s.mapTiles), s.done)
end

function Undo()
    global gUndoDepth
    global gUndoState
    global s
    println("Old undo depth: $(gUndoDepth)")
    gUndoDepth -= 1
    if gUndoDepth <= 1
        gUndoDepth = 1
    end

    s = gUndoState[gUndoDepth]
    s = MazeBuildState(s.xMax, s.yMax, s.fig, s.mazeAxis, deepcopy(s.cursor), deepcopy(s.mapTiles), s.done)
    println("New undo depth: $(gUndoDepth)")
end


function RunMapBuilder()
    global s
    global gUndoDepth
    global gUndoState
    println("Welcome to the map builder!")

    fig = Figure(; size=(1600, 900))
    axis = Axis(fig[1, 1])

    textAxis = Axis(fig[1, 2])
    text!(textAxis, "Map Builder")

    hidedecorations!(axis)
    hidedecorations!(textAxis)
    axis.aspect = DataAspect()

    mapTiles = Matrix{MutableMapTile}(undef, 1, 1)
    mapTiles[1, 1] = CreateDefault(Int32(1), Int32(1))


    s = MazeBuildState(1, 1, fig, axis, Cursor(1, 1), mapTiles, false)
    stateCopy = MazeBuildState(s.xMax, s.yMax, s.fig, s.mazeAxis, deepcopy(s.cursor), deepcopy(s.mapTiles), s.done)
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


    while s.done == false
        sleep(0.5)
    end
    println("Broke out of the sleeping loop")
    GLMakie.closeall()
end