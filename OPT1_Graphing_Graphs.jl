







function OPT1_ProduceGraph_Speedup(reportStructs::Vector{OPT1_BenchmarkingReportStruct})
    error("Not Implemented")
end

function OPT1_ProduceGraph_TotalTime(reportStructs::Vector{OPT1_BenchmarkingReportStruct}, legendOnTop)
    fig = OPT1_CreateFigure() # Semicolon necessary to stop it from showing up? maybe
    title = OPT1_CreateGraphTitle(reportStructs, "Time to solve paths")
    axis = OPT1_CreateGraphAxis(reportStructs, fig, "Solve duration (seconds)", title)

    # Sorting along the x axis of the eventual figure
    sortedReportStructs = sort(reportStructs, by=x -> x.workerCount)

    #= 3 lines:
    1. ST (which is a single point)
    2. Initial
    3. Beauty
    =#
    # stPoint
    st_Xs = [0]
    st_Ys = ToMs([sortedReportStructs[1].st_seconds])

    sharedXs = []
    initialYs = []
    beautyYs = []
    idealYs = []

    for reportStruct::OPT1_BenchmarkingReportStruct in sortedReportStructs
        push!(sharedXs, reportStruct.workerCount)
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

    legendPosition = if legendOnTop
        :rt
    else
        :rb
    end
    GR_CreateLegend(axis, "Seconds to build path", legendPosition)
    # axislegend(axis, "Seconds to build path", position=legendPosition, backgroundcolor=RGBA(1, 1, 1, 0.7))

    return fig
end



function OPT1_ProduceGraph_PathCost(reportStructs::Vector{OPT1_BenchmarkingReportStruct})
    fig = OPT1_CreateFigure()
    title = OPT1_CreateGraphTitle(reportStructs, ": Path Cost")
    axis = OPT1_CreateGraphAxis(reportStructs, fig, "Path Cost", title)
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



