using Statistics
const GRAPH_POINT_SIZE = 10
const BEAUTY_COLOR = :red
const INITIAL_COLOR = :green
const ST_COLOR = :blue
const IDEAL_COLOR = :magenta

const WORST_COLOR = :red
const BEST_COLOR = :green
const AVERAGE_COLOR = :blue

include("CenStar_Graphing_Graphs.jl")



# File names are squished between --- ---
function GetMapNameFromFile(fileName::String)
    partsSplitter = split(fileName, "---")
    @assert length(partsSplitter) == 3 "Filename was incorrect, couldn't get the map name: $fileName"

    scalingLevel = split((split(fileName, "ScalingLevel")[2]), ".BEN")[1]

    mapName = "$(partsSplitter[2])_ScalingLevel$scalingLevel"
    return mapName
end



function CenStar_GetFigureSize()
    scaler = 0.8
    return (1000, 600) .* scaler
end

function GR_CreateLegend(axis, legendTitle, legendOnTop)
    # axislegend(axis, legendTitle, position=GR_GetLegendPosition(legendOnTop), backgroundcolor=RGBA(1, 1, 1, 0.7))
    axislegend(axis, position=GR_GetLegendPosition(legendOnTop), backgroundcolor=RGBA(1, 1, 1, 0.7))
end

function GR_GetLegendPosition(legendOnTop::Bool)
    return if legendOnTop
        :rt
    else
        :rb
    end
end

function GR_GetSortedReportStructs(reportStructs::Vector{CenStar_BenchmarkingReportStruct})
    return sort(reportStructs, by=x -> x.workerCount)
end

function GR_GetSharedXs_WorkerCount(sortedReportStructs::Vector{CenStar_BenchmarkingReportStruct})
    sharedXs = []
    for reportStruct::CenStar_BenchmarkingReportStruct in sortedReportStructs
        push!(sharedXs, reportStruct.workerCount)
    end
    return sharedXs
end

function GR_CreateFigure()
    return Figure(; size=CenStar_GetFigureSize())
end


function GR_LineAndPoints!(axis, xs, ys, color, label; dotted=false)
    GR_Lines!(axis, xs, ys, color, label, dotted=dotted)
    GR_Scatter!(axis, xs, ys, color)
end

function GR_Lines!(axis, xs, ys, color, label; dotted=false)
    linestyle = if dotted
        :dot
    else
        :solid
    end

    lines!(axis, xs, ys, color=color, label=label, linestyle=linestyle)
end

function GR_Scatter!(axis, xs, ys, color)
    scatter!(axis, xs, ys, color=color, markersize=GRAPH_POINT_SIZE)
end


function GR_CreateGraphTitle(reportStructs::Vector{CenStar_BenchmarkingReportStruct}, descriptionPart::String)
    mapNamePretty = reportStructs[1].mapName
    mapNamePretty = replace(mapNamePretty, "_" => " ")
    mapNamePretty = replace(mapNamePretty, "Seed" => "SEEDSTART")

    mapNamePretty = replace(mapNamePretty, " Width:" => ", SEEDEND(Width:")
    mapNamePretty = replace(mapNamePretty, " Height:" => ", Height:")
    mapNamePretty = "$mapNamePretty)"

    firstPart = split(mapNamePretty, "SEEDSTART")[1]
    secondPart = split(mapNamePretty, "SEEDEND")[2]

    mapNamePretty = "$firstPart$secondPart"
    # println("Map name before: $(reportStructs[1].mapName), after: $mapNamePretty")
    return "$mapNamePretty - $(descriptionPart)"
end

function GR_CreateGraphAxis_CustomRange(reportStructs::Vector{CenStar_BenchmarkingReportStruct}, fig, ylabel, title, min, max, interval; xlabel="Worker Count")
    sortedWorkerCounts = sort(unique([r.workerCount for r in reportStructs]), by=x -> x)
    workerLabels = [string(v) for v in sortedWorkerCounts]
    xTicks = (sortedWorkerCounts, workerLabels)

    yTicks = []
    current = min
    while current < max
        push!(yTicks, current)
        current += interval
    end

    return Axis(
        fig[1, 1],
        xlabel=xlabel,
        ylabel=ylabel,
        title=title,
        xticks=xTicks,
        yticks=yTicks,
        yscale=identity,
        xscale=log2
    )

end

function GR_CreateGraphAxis_LinearY(reportStructs::Vector{CenStar_BenchmarkingReportStruct}, fig, ylabel, title)
    sortedWorkerCounts = sort(unique([r.workerCount for r in reportStructs]), by=x -> x)

    workerLabels = [string(v) for v in sortedWorkerCounts]
    xTicks = (sortedWorkerCounts, workerLabels)
    xlabel = "Worker Count"

    axis = Axis(
        fig[1, 1],
        xlabel=xlabel,
        ylabel=ylabel,
        title=title,
        xticks=xTicks,
        yscale=identity,
        xscale=log2
    )

    return axis
end
function GR_CreateGraphAxis_LinearY_Increments(reportStructs::Vector{CenStar_BenchmarkingReportStruct}, fig, ylabel, title, minVal, maxVal)
    sortedWorkerCounts = sort(unique([r.workerCount for r in reportStructs]), by=x -> x)

    workerLabels = [string(v) for v in sortedWorkerCounts]
    xTicks = (sortedWorkerCounts, workerLabels)
    xlabel = "Worker Count"

    yTicks = []
    current = minVal
    increment = (maxVal - minVal) / 10
    while current < maxVal
        push!(yTicks, current)
        current += increment
    end

    axis = Axis(
        fig[1, 1],
        xlabel=xlabel,
        ylabel=ylabel,
        title=title,
        xticks=xTicks,
        yticks=yTicks,
        yscale=identity,
        xscale=log2
    )

    return axis

end

function GR_CreateGraphAxis(reportStructs::Vector{CenStar_BenchmarkingReportStruct}, fig, ylabel, title; xlabel="Worker Count")

    sortedWorkerCounts = sort(unique([r.workerCount for r in reportStructs]), by=x -> x)
    # TODO: perhaps label the lhs as actual miliseconds, rather than 2^something. At least be an option. ask prof

    workerLabels = [string(v) for v in sortedWorkerCounts]
    xTicks = (sortedWorkerCounts, workerLabels)

    return Axis(
        fig[1, 1],
        xlabel=xlabel,
        ylabel=ylabel,
        title=title,
        xticks=xTicks,
        yscale=log2,
        xscale=log2
    )
end




function _GetAllBenchmarkFilesInDirectory(folderPath::String, files)
    for file in readdir(folderPath)
        fileOrFolderPath = joinpath(folderPath, file)
        if isfile(fileOrFolderPath) && endswith(file, ".BENCHMARK")
            if endswith(file, ".BENCHMARK")
                push!(files, fileOrFolderPath)
            end
        elseif isdir(fileOrFolderPath)
            _GetAllBenchmarkFilesInDirectory(fileOrFolderPath, files)
        end
    end
end

function GetAllBenchmarkFilesInDirectory(folderPath::String)
    files = []
    _GetAllBenchmarkFilesInDirectory(folderPath, files)
    return files
end

function CenStar_ProduceBenchmarkingGraphs_V2(folderPath::String)
    if isdir(folderPath) == false
        error("Folder $(folderPath) does not exist")
    end

    benchmarkingFiles = GetAllBenchmarkFilesInDirectory(folderPath)
    println("Read $(length(benchmarkingFiles)) benchmarking files")

    mapNameAndReportStructs = Dict{String,Vector{CenStar_BenchmarkingReportStruct}}()
    for benchmarkingFile in benchmarkingFiles
        try
            deserialized::CenStar_BenchmarkingReportStruct = open(benchmarkingFile, "r") do file
                deserialize(file)
            end

            # try
            mapName = GetMapNameFromFile(benchmarkingFile)
            # catch e
            #     println("Failed to get map name from $benchmarkingFile, probably outdated file that should be deleted")
            #     continue
            # end

            if haskey(mapNameAndReportStructs, mapName) == false
                mapNameAndReportStructs[mapName] = Vector{CenStar_BenchmarkingReportStruct}()
            end
            push!(mapNameAndReportStructs[mapName], deserialized)
        catch e
            println("An error occurred trying to deserialize the benchmarking file $benchmarkingFile $(e)")
            continue
        end
    end
    println("Deserialized the benchmarking files")

    # Preparing the figures directory
    figureDirectory = joinpath(folderPath, "Figures")
    if isdir(figureDirectory)
        attempts = 0
        success = false
        while attempts < 10
            try
                rm(figureDirectory; recursive=true, force=true)
                success = true
                break
            catch
                attempts += 1
                sleep(0.3)
            end
        end

        if success == false
            println("Failed to clear the old directory in $attempts attempts")
            return
        end
        println("Cleared the old directory: $figureDirectory, which took $attempts attempts")
    end
    mkpath(figureDirectory)

    graphsProduced = 0
    for (mapName::String, reportStructs::Vector{CenStar_BenchmarkingReportStruct}) in mapNameAndReportStructs
        mapGraphs = Vector{Tuple{GLMakie.Figure,String}}()

        push!(mapGraphs, (GR_ProduceGraph_TotalTime(reportStructs, true), "TotalTime"))
        push!(mapGraphs, (GR_ProduceGraph_TotalTime(reportStructs, false), "TotalTime"))

        push!(mapGraphs, (GR_ProduceGraph_Speedup(reportStructs, true), "Speedup"))
        push!(mapGraphs, (GR_ProduceGraph_Speedup(reportStructs, false), "Speedup"))

        push!(mapGraphs, (GR_ProduceGraph_ComputationFraction(reportStructs, true), "ComputationFraction"))
        push!(mapGraphs, (GR_ProduceGraph_ComputationFraction(reportStructs, false), "ComputationFraction"))

        push!(mapGraphs, (GR_ProduceGraph_TilesReceivedVsTilesExplored(reportStructs, true), "TilesReceivedVsExplored"))
        push!(mapGraphs, (GR_ProduceGraph_TilesReceivedVsTilesExplored(reportStructs, false), "TilesReceivedVsExplored"))

        # push!(mapGraphs, CenStar_ProduceGraph_PathCost(reportStructs))
        legendOnTop = true
        for (i, (graph, graphName)) in enumerate(mapGraphs)
            legendDescription = if legendOnTop
                "LT"
            else
                "LB"
            end
            fileName = "BenchFig_$(graphName)_$(mapName)_$legendDescription.png"
            save(joinpath(figureDirectory, fileName), graph, size=CenStar_GetFigureSize())
            graphsProduced += 1
            println("Saved the graph $fileName")
            legendOnTop = !legendOnTop
        end
    end

    println("Done! We produced $graphsProduced graphs")
end


function ToMs(inSeconds)
    return inSeconds * 1000
end


# end