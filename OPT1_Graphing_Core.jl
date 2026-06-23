using Statistics
const GRAPH_POINT_SIZE = 10
const BEAUTY_COLOR = :red
const INITIAL_COLOR = :green
const ST_COLOR = :blue
const IDEAL_COLOR = :magenta

include("OPT1_Graphing_Graphs.jl")



# File names are squished between --- ---
function GetMapNameFromFile(fileName::String)
    parts = split(fileName, "---")
    @assert length(parts) == 3 "Filename was incorrect, couldn't get the map name: $fileName"
    return parts[2]
end



function OPT1_GetFigureSize()
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

function GR_GetSortedReportStructs(reportStructs::Vector{OPT1_BenchmarkingReportStruct})
    return sort(reportStructs, by=x -> x.workerCount)
end

function GR_GetSharedXs_WorkerCount(sortedReportStructs::Vector{OPT1_BenchmarkingReportStruct})
    sharedXs = []
    for reportStruct::OPT1_BenchmarkingReportStruct in sortedReportStructs
        push!(sharedXs, reportStruct.workerCount)
    end
    return sharedXs
end

function GR_CreateFigure()
    return Figure(; size=OPT1_GetFigureSize())
end

function GR_Lines!(axis, xs, ys, color, label)
    lines!(axis, xs, ys, color=color, label=label)
end

function GR_Scatter!(axis, xs, ys, color)
    scatter!(axis, xs, ys, color=color, markersize=GRAPH_POINT_SIZE)
end


function GR_CreateGraphTitle(reportStructs::Vector{OPT1_BenchmarkingReportStruct}, descriptionPart::String)
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

function GR_CreateGraphAxis(reportStructs::Vector{OPT1_BenchmarkingReportStruct}, fig, ylabel, title; xlabel="Worker Count")
    # sortedWorkerCounts = []
    # push!(workerValues, 1)
    # currentProcessor = 1
    # processorMax = maximum(p.workerCount for p in reportStructs)

    sortedWorkerCounts = sort(unique([r.workerCount for r in reportStructs]), by=x -> x)
    # for workerCount in sortedWorkerCounts
    #     push!(sortedWorkerCounts, workerCount)
    # end
    # while currentProcessor < processorMax
    #     currentProcessor *= 2
    #     push!(workerValues, currentProcessor)

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

function OPT1_ProduceBenchmarkingGraphs_V2(folderPath::String)
    if isdir(folderPath) == false
        error("Folder $(folderPath) does not exist")
    end

    benchmarkingFiles = GetAllBenchmarkFilesInDirectory(folderPath)
    println("Read $(length(benchmarkingFiles)) benchmarking files")

    mapNameAndReportStructs = Dict{String,Vector{OPT1_BenchmarkingReportStruct}}()
    for benchmarkingFile in benchmarkingFiles
        try
            deserialized::OPT1_BenchmarkingReportStruct = open(benchmarkingFile, "r") do file
                deserialize(file)
            end

            mapName = GetMapNameFromFile(benchmarkingFile)
            if haskey(mapNameAndReportStructs, mapName) == false
                mapNameAndReportStructs[mapName] = Vector{OPT1_BenchmarkingReportStruct}()
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
    for (mapName::String, reportStructs::Vector{OPT1_BenchmarkingReportStruct}) in mapNameAndReportStructs
        mapGraphs = Vector{GLMakie.Figure}()

        push!(mapGraphs, GR_ProduceGraph_TotalTime(reportStructs, true);)
        push!(mapGraphs, GR_ProduceGraph_TotalTime(reportStructs, false))
        push!(mapGraphs, GR_ProduceGraph_Speedup(reportStructs, true))
        push!(mapGraphs, GR_ProduceGraph_Speedup(reportStructs, false))
        # push!(mapGraphs, OPT1_ProduceGraph_PathCost(reportStructs))
        legendOnTop = true
        for (i, graph) in enumerate(mapGraphs)
            legendDescription = if legendOnTop
                "legendOnTop"
            else
                "legendOnBottom"
            end
            fileName = "BenchmarkFigure_$(mapName)_$(i)_$legendDescription.png"
            save(joinpath(figureDirectory, fileName), graph, size=OPT1_GetFigureSize())
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


# function OPT1_ProduceBenchmarkGraphs_V1(folderPath::String)
#     if isdir(folderPath) == false
#         error("Folder $(folderPath) does not exist")
#     end

#     graphAxes::Vector{GLMakie.Axis} = []


#     mapNameAndFiles = Dict{String,Vector{OPT1_BenchmarkingReportStruct}}()
#     for file in readdir(folderPath)
#         filePath = joinpath(folderPath, file)
#         if isfile(filePath) == false
#             println("Found something thaht wasn't a file: $file")
#             continue
#         end
#         println("Read a file $file")


#         deserialized::OPT1_BenchmarkingReportStruct = open(filePath, "r") do file
#             deserialize(file)
#         end

#         mapName = GetMapNameFromFile(file)
#         if haskey(mapNameAndFiles, mapName) == false
#             mapNameAndFiles[mapName] = Vector{OPT1_BenchmarkingReportStruct}()
#         end
#         push!(mapNameAndFiles[mapName], deserialized)
#     end

#     mapCount = length(keys(mapNameAndFiles))


#     figureDirectory = joinpath(folderPath, "Figures")
#     mkpath(figureDirectory)
#     for file in readdir(figureDirectory, join=true)
#         if isfile(file)
#             rm(file)
#         end
#     end

#     currentFig = Figure(; size=(1600, 900))
#     figs = [currentFig]
#     axesInFig = 0

#     println("Keys: $(keys(mapNameAndFiles))")

#     currentColumn = 1
#     sortedKeys = sort(collect(keys(mapNameAndFiles)); by=key -> (length(key), key))
#     # for key in sort(collect(keys(mapNameAndFiles)))
#     for key in sortedKeys

#         println("There are $(length(mapNameAndFiles[key])) entries for map $(key)")
#         # For every map:

#         # First row: Time to complete
#         push!(graphAxes, OPT1_ProduceGraph_TotalTime(mapNameAndFiles[key], currentFig, 1, currentColumn))

#         # Second row: Path cost
#         push!(graphAxes, OPT1_ProduceGraph_PathCost(mapNameAndFiles[key], currentFig, 2, currentColumn))
#         axesInFig += 2
#         currentColumn += 1

#         if axesInFig >= 4
#             currentFig = Figure(; size=(1600, 900))
#             push!(figs, currentFig)
#             axesInFig = 0
#             currentColumn = 1
#         end
#     end


#     # First row: totalTime, maps on the horizontal

#     # Second row: Map Cost, maps on the horizontal

#     for (i, fig) in enumerate(figs)
#         save(joinpath(figureDirectory, "BenchmarkFigure_$(i).png"), fig, size=(1600, 900))
#         # display(fig)
#     end

#     # println("Press enter to Exit!")
#     # readline()
#     GLMakie.closeall()
#     println("Done!")
#     # println("Exiting...")
# end