







function GR_ProduceGraph_Speedup(reportStructs::Vector{OPT1_BenchmarkingReportStruct}, legendOnTop::Bool)
    fig = GR_CreateFigure()
    title = GR_CreateGraphTitle(reportStructs, "Speedup")
    axis = GR_CreateGraphAxis(reportStructs, fig, "Speedup", title)
    sortedReportStructs = GR_GetSortedReportStructs(reportStructs)
    stSolve = sortedReportStructs[1].st_seconds
    st_Ys = [1]
    sharedXs = GR_GetSharedXs_WorkerCount(sortedReportStructs)

    initialYs = []
    beautyYs = []
    idealYs = []

    for r::OPT1_BenchmarkingReportStruct in sortedReportStructs

        initialSpeedup = stSolve / r.secondsFromStartToHavingReceivedAllInitialPaths
        push!(initialYs, initialSpeedup)

        beautySpeedup = stSolve / r.secondsFromStartToHavingReceivedAllBeautifiedPaths
        push!(beautyYs, beautySpeedup)

        idealSpeedup = r.workerCount
        push!(idealYs, idealSpeedup)
    end

    hlines!(axis, st_Ys[1], color=ST_COLOR, label="Single=threaded")

    GR_Lines!(axis, sharedXs, initialYs, INITIAL_COLOR, "Initial path")
    GR_Scatter!(axis, sharedXs, initialYs, INITIAL_COLOR)

    GR_Lines!(axis, sharedXs, beautyYs, BEAUTY_COLOR, "Beautfied path")
    GR_Scatter!(axis, sharedXs, beautyYs, BEAUTY_COLOR)

    GR_Lines!(axis, sharedXs, idealYs, IDEAL_COLOR, "Ideal speedup")
    GR_Scatter!(axis, sharedXs, idealYs, BEAUTY_COLOR)

    GR_CreateLegend(axis, "Speedup", legendOnTop)

    return fig
end

function GR_ProduceGraph_TotalTime(reportStructs::Vector{OPT1_BenchmarkingReportStruct}, legendOnTop)
    fig = GR_CreateFigure() # Semicolon necessary to stop it from showing up? maybe
    title = GR_CreateGraphTitle(reportStructs, "Time to solve paths")
    axis = GR_CreateGraphAxis(reportStructs, fig, "Solve duration (Miliseconds)", title)
    sortedReportStructs = GR_GetSortedReportStructs(reportStructs)

    # Sorting along the x axis of the eventual figure
    #= 3 lines:
    1. ST (which is a single point)
    2. Initial
    3. Beauty
    =#
    # stPoint
    st_Ys = ToMs([sortedReportStructs[1].st_seconds])

    sharedXs = GR_GetSharedXs_WorkerCount(sortedReportStructs)
    initialYs = []
    beautyYs = []
    idealYs = []

    for reportStruct::OPT1_BenchmarkingReportStruct in sortedReportStructs
        push!(initialYs, ToMs(reportStruct.secondsFromStartToHavingReceivedAllInitialPaths))
        push!(beautyYs, ToMs(reportStruct.secondsFromStartToHavingReceivedAllBeautifiedPaths))
        push!(idealYs, st_Ys[1] / reportStruct.workerCount)
    end

    # lines!(axis, st_Xs, st_Ys, color=ST_COLOR, label="Single-threaded uhh whats this about")
    # scatter!(axis, st_Xs, st_Ys, color=ST_COLOR, markersize=GRAPH_POINT_SIZE)

    hlines!(axis, st_Ys[1], color=ST_COLOR, label="Single-threaded")

    lines!(axis, sharedXs, initialYs, color=INITIAL_COLOR, label="Initial path")
    scatter!(axis, sharedXs, initialYs, color=INITIAL_COLOR, markersize=GRAPH_POINT_SIZE)

    lines!(axis, sharedXs, beautyYs, color=BEAUTY_COLOR, label="Beautified path")
    scatter!(axis, sharedXs, beautyYs, color=BEAUTY_COLOR, markersize=GRAPH_POINT_SIZE)

    lines!(axis, sharedXs, idealYs, color=IDEAL_COLOR, label="Ideal solve")
    scatter!(axis, sharedXs, idealYs, color=IDEAL_COLOR, markersize=GRAPH_POINT_SIZE)

    GR_CreateLegend(axis, "Seconds to build path", legendOnTop)

    return fig
end



function GR_ProduceGraph_PathCost(reportStructs::Vector{OPT1_BenchmarkingReportStruct})
    fig = GR_CreateFigure()
    title = GR_CreateGraphTitle(reportStructs, ": Path Cost")
    axis = GR_CreateGraphAxis(reportStructs, fig, "Path Cost", title)
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



