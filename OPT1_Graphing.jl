using Statistics
const GRAPH_POINT_SIZE = 10
const BEAUTY_COLOR = :red
const INITIAL_COLOR = :green
const ST_COLOR = :blue

# File names are squished between --- ---
function GetMapNameFromFile(fileName::String)
    parts = split(fileName, "---")
    @assert length(parts) == 3 "Filename was incorrect, couldn't get the map name: $fileName"
    return parts[2]
end


function OPT1_GenerateReportFilename(reportStruct::OPT1_BenchmarkingReportStruct)
    mapName = replace(reportStruct.mapName, ":" => "x")
    fileName::String = "OPT1_---$(mapName)---_$(reportStruct.workerCount+1)Ranks.BENCHMARK"
end


function OPT1_CreateGraphAxis(reportStructs::Vector{OPT1_BenchmarkingReportStruct}, fig, row, column, xlabel, ylabel, title)
    processorValues = []
    push!(processorValues, 1)
    currentProcessor = 1
    processorMax = maximum(p.workerCount + 1 for p in reportStructs)

    multithreadedProcessorCounts = sort(unique([r.workerCount + 1 for r in reportStructs]), by=x -> x)
    for m in multithreadedProcessorCounts
        push!(processorValues, m)
    end
    # while currentProcessor < processorMax
    #     currentProcessor *= 2
    #     push!(processorValues, currentProcessor)
    # end

    processorLabels = [string(v) for v in processorValues]
    xTicks = (processorValues, processorLabels)

    return Axis(
        fig[row, column],
        xlabel=xlabel,
        ylabel=ylabel,
        title=title,
        xticks=xTicks,
        # yscale=log2,
        # xscale=log2
    )
end

function OPT1_CreateGraphTitle(reportStructs::Vector{OPT1_BenchmarkingReportStruct}, descriptionPart::String)
    return "$(reportStructs[1].mapName) - $(descriptionPart)"
end

function OPT1_ProduceGraph_totalTime(reportStructs::Vector{OPT1_BenchmarkingReportStruct}, fig, row, column)
    title = OPT1_CreateGraphTitle(reportStructs, "Time to solve paths")
    axis = OPT1_CreateGraphAxis(reportStructs, fig, row, column, "Processor Count", "Solve duration (seconds)", title)

    # Sorting along the x axis of the eventual figure
    sortedReportStruct = sort(reportStructs, by=x -> x.workerCount)

    #= 3 lines:
    1. ST (which is a single point)
    2. Initial
    3. Beauty
    =#
    # stPoint
    st_Xs = [0]
    st_Ys = [sortedReportStruct[1].st_seconds] * 1000

    sharedXs = []
    initialYs = []
    beautyYs = []

    for reportStruct::OPT1_BenchmarkingReportStruct in sortedReportStruct
        push!(sharedXs, reportStruct.workerCount)
        push!(initialYs, reportStruct.secondsFromStartToHavingReceivedAllInitialPaths * 1000)
        push!(beautyYs, reportStruct.secondsFromStartToHavingReceivedAllBeautifiedPaths * 1000)
    end

    lines!(axis, st_Xs, st_Ys, color=ST_COLOR, label="Single Threaded Seconds")
    scatter!(axis, st_Xs, st_Ys, color=ST_COLOR, markersize=GRAPH_POINT_SIZE)

    hlines!(axis, st_Ys[1], color=ST_COLOR, label="Single threaded Seconds")

    lines!(axis, sharedXs, initialYs, color=INITIAL_COLOR, label="Initial path seconds(Miliseconds)")
    scatter!(axis, sharedXs, initialYs, color=INITIAL_COLOR, markersize=GRAPH_POINT_SIZE)

    lines!(axis, sharedXs, beautyYs, color=BEAUTY_COLOR, label="Beautified path (Miliseconds)")
    scatter!(axis, sharedXs, beautyYs, color=BEAUTY_COLOR, markersize=GRAPH_POINT_SIZE)

    axislegend(axis, "Seconds to build path", position=:rb)

    return axis
end



function OPT1_ProduceGraph_pathCost(reportStructs::Vector{OPT1_BenchmarkingReportStruct}, fig, row, column)
    title = OPT1_CreateGraphTitle(reportStructs, ": Path Cost")
    axis = OPT1_CreateGraphAxis(reportStructs, fig, row, column, "Processor Count", "Path Cost", title)
    axis.backgroundcolor = :lightgrey
    # axis.aspect = DataAspect() # Makes the y and x axis scaled equally.

    # Right now there's some duplication: each report struct for this map has the st seconds and cost, each computed
    # by hand. Obviously not necessary. Will resolve that later TODO
    stCost = reportStructs[1].st_cost

    sortedReportStruct = sort(reportStructs, by=x -> x.workerCount)

    initialPoints = [(0, stCost)]
    beautyPoints = [(0, stCost)]

    for reportStruct::OPT1_BenchmarkingReportStruct in sortedReportStruct
        initialPoint = (reportStruct.workerCount, reportStruct.initialPathCost)
        beautyPoint = (reportStruct.workerCount, reportStruct.beautifiedPathCost)
        push!(initialPoints, initialPoint)
        push!(beautyPoints, beautyPoint)
    end

    initialXs = [i[1] for i in initialPoints]
    beautyXs = [b[1] for b in beautyPoints]

    initialYs = [i[2] for i in initialPoints]
    beautyYs = [b[2] for b in beautyPoints]

    lines!(axis, initialXs, initialYs, color=INITIAL_COLOR, label="Initial Path Cost")
    scatter!(axis, initialXs, initialYs, color=INITIAL_COLOR, markersize=GRAPH_POINT_SIZE)


    lines!(axis, beautyXs, beautyYs, color=BEAUTY_COLOR, label="Beautified Path Cost")
    scatter!(axis, beautyXs, beautyYs, color=BEAUTY_COLOR, markersize=GRAPH_POINT_SIZE)

    axislegend(
        axis,
        "Path cost",
        position=:rb
    )
    return axis
end






function OPT1_ProduceBenchmarkGraphs(folderPath::String)
    if isdir(folderPath) == false
        error("Folder $(folderPath) does not exist")
    end

    graphAxes::Vector{GLMakie.Axis} = []


    mapNameAndFiles = Dict{String,Vector{OPT1_BenchmarkingReportStruct}}()
    for file in readdir(folderPath)
        filePath = joinpath(folderPath, file)
        if isfile(filePath) == false
            continue
        end


        deserialized::OPT1_BenchmarkingReportStruct = open(filePath, "r") do file
            deserialize(file)
        end

        mapName = GetMapNameFromFile(file)
        if haskey(mapNameAndFiles, mapName) == false
            mapNameAndFiles[mapName] = Vector{OPT1_BenchmarkingReportStruct}()
        end
        push!(mapNameAndFiles[mapName], deserialized)
    end

    mapCount = length(keys(mapNameAndFiles))


    figureDirectory = joinpath(folderPath, "Figures")
    mkpath(figureDirectory)
    for file in readdir(figureDirectory, join=true)
        if isfile(file)
            rm(file)
        end
    end

    currentFig = Figure(; size=(1600, 900))
    figs = [currentFig]
    axesInFig = 0

    currentColumn = 1
    sortedKeys = sort(collect(keys(mapNameAndFiles)); by=key -> (length(key), key))
    # for key in sort(collect(keys(mapNameAndFiles)))
    for key in sortedKeys

        println("There are $(length(mapNameAndFiles[key])) entries for map $(key)")
        # For every map:

        # First row: Time to complete
        push!(graphAxes, OPT1_ProduceGraph_totalTime(mapNameAndFiles[key], currentFig, 1, currentColumn))

        # Second row: Path cost
        push!(graphAxes, OPT1_ProduceGraph_pathCost(mapNameAndFiles[key], currentFig, 2, currentColumn))
        axesInFig += 2
        currentColumn += 1

        if axesInFig >= 4
            currentFig = Figure(; size=(1600, 900))
            push!(figs, currentFig)
            axesInFig = 0
            currentColumn = 1
        end
    end


    # First row: totalTime, maps on the horizontal

    # Second row: Map Cost, maps on the horizontal

    for (i, fig) in enumerate(figs)
        save(joinpath(figureDirectory, "BenchmarkFigure_$(i).png"), fig, size=(1600, 900))
        # display(fig)
    end

    # println("Press enter to Exit!")
    # readline()
    GLMakie.closeall()
    println("Done!")
    # println("Exiting...")
end
