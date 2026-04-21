const PATHCOST_Wall = 20
const PATHCOST_Default = 5
const PATHCOST_BoostPad = 1
const PATHCOST_Mud = 7
const PATHCOST_Water = 13
const PATHCOST_Border = -99

const PATHCOLOR_Default = :white
const PATHCOLOR_Wall = :black
const PATHCOLOR_Traversed = :green
const PATHCOLOR_Tested = :teal
const PATHCOLOR_Water = :blue
const PATHCOLOR_Mud = :brown
const PATHCOLOR_BoostPad = :orange
const PATHCOLOR_MapBorder = :silver


function CreateWall(x::Int32, y::Int32)
    return MapTile(x, y, costToReach=PATHCOST_Wall)
end

function CreateDefault(x::Int32, y::Int32)
    return MapTile(x, y, costToReach=PATHCOST_Default)
end

function CreateMapBorder(x::Int32, y::Int32)
    return MapTile(x, y, costToReach=PATHCOST_Border)
end


function ConvertToDefault!(mapTile::MapTile)
    mapTile.costToReach = PATHCOST_Default
end



function ConvertToWater!(mapTile::MapTile)
    mapTile.costToReach = PATHCOST_Water
end

function ConvertToMud!(mapTile::MapTile)
    mapTile.costToReach = PATHCOST_Mud
end

function ConvertToBoostPad!(mapTile::MapTile)
    mapTile.costToReach = PATHCOST_BoostPad
end



function LoadNeighbors!(tiles::Array{MapTile})
    @assert false "Don't use this function. Don't have references to tiles within tiles."
    allTilesDict = Dict{Tuple{Int,Int},MapTile}()
    for mapTile::MapTile in tiles
        allTilesDict[(mapTile.x, mapTile.y)] = mapTile
    end
    println("Loaded up the dict with $(length(tiles)) potential neighbors")

    for mapTile::MapTile in tiles
        northKey = (mapTile.x, mapTile.y + 1)
        northTile = get(allTilesDict, northKey, nothing)
        if northTile !== nothing
            push!(mapTile.neighbors, northTile)
        end

        eastKey = (mapTile.x + 1, mapTile.y)
        eastTile = get(allTilesDict, eastKey, nothing)
        if eastTile !== nothing
            push!(mapTile.neighbors, eastTile)
        end

        southKey = (mapTile.x, mapTile.y - 1)
        southTile = get(allTilesDict, southKey, nothing)
        if southTile !== nothing
            push!(mapTile.neighbors, southTile)
        end

        westKey = (mapTile.x - 1, mapTile.y)
        westTile = get(allTilesDict, westKey, nothing)
        if westTile !== nothing
            push!(mapTile.neighbors, westTile)
        end
    end
end


function PlaceBlob!(allTilesDict::Dict{Tuple{Int32,Int32},MapTile}, x::Int32, y::Int32, size::Int32, identifier)


    blobXMin::Int32 = x - (size ÷ 2)
    blobXMax::Int32 = x + (size ÷ 2)

    blobYMin::Int32 = y - (size ÷ 2)
    blobYMax::Int32 = y + (size ÷ 2)

    tilesToModify = MapTile[]
    for x in blobXMin:blobXMax, y in blobYMin:blobYMax
        tileToModify = get(allTilesDict, (x, y), nothing)
        # tileToModify = FindExistingMapTile(x, y, pathTiles)
        if tileToModify !== nothing
            push!(tilesToModify, tileToModify)
        end
    end

    if identifier == :DirtBlob
        for tile in tilesToModify
            ConvertToMud!(tile)
        end
    elseif identifier == :WaterBlob
        for tile in tilesToModify
            ConvertToWater!(tile)
        end
    elseif identifier == :BoostBlob
        for tile in tilesToModify
            ConvertToBoostPad!(tile)
        end
    else
        error("Identifier $identifier is not yet suported for placing blobs")
    end
end




function PlaceBlobs(pathMapTiles::Array{MapTile}, xMin::Int32, xMax::Int32, yMin::Int32, yMax::Int32, identifier)

    maxBlobDivider = if identifier == :DirtBlob
        100
    elseif identifier == :WaterBlob
        300
    elseif identifier == :BoostBlob
        300
    else
        error("Identifier $identifier is not supported")
    end

    maxBlobs::Int32 = ((xMax * yMax) ÷ maxBlobDivider)
    minBlobs::Int32 = maxBlobs ÷ 5
    blobCount::Int32 = rand(minBlobs:maxBlobs)

    maxBlobSize::Int32 = if identifier == :DirtBlob
        16
    elseif identifier == :WaterBlob
        25
    elseif identifier == :BoostBlob
        12
    else
        error("Identifier $identifier is not supported")
    end

    minBlobSize::Int32 = maxBlobSize ÷ 4
    if minBlobSize < 1
        minBlobSize = 1
    end

    println("Going to place $blobCount blobs of $identifier")

    allTilesDict = Dict{Tuple{Int32,Int32},MapTile}()
    for mapTile::MapTile in pathMapTiles
        allTilesDict[(mapTile.x, mapTile.y)] = mapTile
    end

    for _ in 1:blobCount
        blobCenter_X::Int32 = rand(xMin:xMax)
        blobCenter_Y::Int32 = rand(yMin:yMax)
        blobSize::Int32 = rand(minBlobSize:maxBlobSize)
        PlaceBlob!(allTilesDict, blobCenter_X, blobCenter_Y, blobSize, identifier)
        # println("Placed a blob with identifier $identifier")
    end
end




function GeneratePathTiles(walls::Array{Tuple{Int32,Int32}}, xMin::Int32, xMax::Int32, yMin::Int32, yMax::Int32)
    println("Going to create default map tiles for everything that is not a wall")
    pathMapTiles = MapTile[]
    wallsSet = Set{Tuple{Int32,Int32}}()
    for wall in walls
        push!(wallsSet, wall)
    end

    for x in xMin:xMax
        for y in yMin:yMax
            if !((x, y) in wallsSet)
                push!(pathMapTiles, CreateDefault(x, y))
            end
        end
    end
    println("Going to place the blobs onto the map")

    PlaceBlobs(pathMapTiles, xMin, xMax, yMin, yMax, :DirtBlob)
    println("Placed dirt")
    PlaceBlobs(pathMapTiles, xMin, xMax, yMin, yMax, :WaterBlob)
    println("Placed water")
    PlaceBlobs(pathMapTiles, xMin, xMax, yMin, yMax, :BoostBlob)
    println("Placed boost")

    # DIRTBLOBS

    return pathMapTiles
end