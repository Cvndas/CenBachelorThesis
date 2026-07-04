




function GR_ProduceGraph_ComputationFraction(reportStructs::Vector{CenStar_BenchmarkingReportStruct}, legendOnTop::Bool)
    fig = GR_CreateFigure()
    title = GR_CreateGraphTitle(reportStructs, "Computation fraction")

    axis = GR_CreateGraphAxis_CustomRange(reportStructs, fig, "Computation Fraction", title, 0, 2, 0.1)

    sortedReportStructs = GR_GetSortedReportStructs(reportStructs)

    sharedXs = GR_GetSharedXs_WorkerCount(sortedReportStructs)
    Ys = []

    for r::CenStar_BenchmarkingReportStruct in sortedReportStructs
        # computation = r.rawComputationSeconds_Initial_BWA.worstVal + r.rawComputationSeconds_Beautify_BWA.worstVal
        computation = r.rawComputationSeconds_Initial_BWA.averageVal + r.rawComputationSeconds_Beautify_BWA.averageVal
        # fraction = 1 / r.secondsFromStartToHavingReceivedAllBeautifiedPaths * computation
        fraction = computation / r.secondsFromStartToHavingReceivedAllBeautifiedPaths

        # println("For maze $(reportStructs[1].mapName) the computation was $computation and the startToBeautified paths was $(r.secondsFromStartToHavingReceivedAllBeautifiedPaths)")
        push!(Ys, fraction)
    end

    hlines!(axis, [1], color=ST_COLOR, label="Pure computation")
    GR_Lines!(axis, sharedXs, Ys, BEAUTY_COLOR, "Computation fraction")

    GR_CreateLegend(axis, "Computation Fraction", legendOnTop)
    return fig
end


function GR_ProduceGraph_TilesReceivedVsTilesExplored(reportStructs::Vector{CenStar_BenchmarkingReportStruct}, legendOnTop::Bool)
    fig = GR_CreateFigure()
    title = GR_CreateGraphTitle(reportStructs, "Tiles Received vs Tiles Explored ")

    # Idea: Dotted line for explored, solid line for received, matching color. Do this for worst, best, average


    sortedReportStructs = GR_GetSortedReportStructs(reportStructs)

    sharedXs = GR_GetSharedXs_WorkerCount(sortedReportStructs)

    Ys_Received_Worst = []
    Ys_Explored_Worst = []

    Ys_Received_Average = []
    Ys_Explored_Average = []

    Ys_Received_Best = []
    Ys_Explored_Best = []

    for r::CenStar_BenchmarkingReportStruct in sortedReportStructs
        push!(Ys_Received_Worst, r.totalTilesReceived_BWA.worstVal)
        push!(Ys_Explored_Worst, r.totalTilesExplored_BWA.worstVal)

        push!(Ys_Received_Average, r.totalTilesReceived_BWA.averageVal)
        push!(Ys_Explored_Average, r.totalTilesExplored_BWA.averageVal)

        push!(Ys_Received_Best, r.totalTilesReceived_BWA.bestVal)
        push!(Ys_Explored_Best, r.totalTilesExplored_BWA.bestVal)
    end

    maxVal = maximum(vcat(Ys_Received_Worst, Ys_Explored_Worst))
    axis = GR_CreateGraphAxis_LinearY_Increments(reportStructs, fig, "Total tiles", title, 0, maxVal)

    GR_LineAndPoints!(axis, sharedXs, Ys_Received_Worst, WORST_COLOR, "Tiles received: Worst case")
    GR_LineAndPoints!(axis, sharedXs, Ys_Explored_Worst, WORST_COLOR, "Tiles explored: Worst case", dotted=true)

    GR_LineAndPoints!(axis, sharedXs, Ys_Received_Average, AVERAGE_COLOR, "Tiles received: Average case")
    GR_LineAndPoints!(axis, sharedXs, Ys_Explored_Average, AVERAGE_COLOR, "Tiles explored: Average case", dotted=true)

    GR_LineAndPoints!(axis, sharedXs, Ys_Received_Best, BEST_COLOR, "Tiles received: Best case")
    GR_LineAndPoints!(axis, sharedXs, Ys_Explored_Best, BEST_COLOR, "Tiles explored: Best case", dotted=true)

    GR_CreateLegend(axis, "Explored vs Received", legendOnTop)

    return fig
end


function GR_ProduceGraph_Speedup(reportStructs::Vector{CenStar_BenchmarkingReportStruct}, legendOnTop::Bool)
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

    for r::CenStar_BenchmarkingReportStruct in sortedReportStructs

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

function GR_ProduceGraph_TotalTime(reportStructs::Vector{CenStar_BenchmarkingReportStruct}, legendOnTop)
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

    for reportStruct::CenStar_BenchmarkingReportStruct in sortedReportStructs
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



function GR_ProduceGraph_PathCost(reportStructs::Vector{CenStar_BenchmarkingReportStruct})
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

    for reportStruct::CenStar_BenchmarkingReportStruct in sortedReportStruct
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



