using Statistics
const GRAPH_POINT_SIZE = 10
const BEAUTY_COLOR = :red
const INITIAL_COLOR = :green
const ST_COLOR = :blue


function HelloWorldFromBenchmarking()
    println("Hello world from Benchmarking!")
end






mutable struct BenchmarkData_WorkerCore
    workerId::Int # WorkerId is workerRank - 1
    numberOfOccasionsMapDataWasNotAvailableAndIHadToWait::Int

    totalMapTilesCollected::Int #TODO
    tilesExplored::Int #TODO

    secondsSpentWaitingForMapDataToComeIn::Float64
    secondsFromReceivingJobToHavingSentBeautifiedPaths::Float64

    secondsWaitingForInitialJobAndMapDataToComeIn::Float64 #TODO
    numberOfTimesNewMapDataWasRequested::Int #TODO

    startTime::Float64
    timeOfReceivingInitialJob::Float64

    secondsFromReceivingJobToHavingSentInitialPaths::Float64
    solvingBeautifiedPathAfterReceivingBeautificationJob::Float64

    waitingForBeautificationJobAfterSolvingInitial::Float64
    rawComputationSeconds_Initial::Float64

    rawComputationSeconds_Beautify::Float64
    numberOfBeautificationJobsCompleted::Int

    timeOfFinishingInitialJob::Float64
    timeOfReceivingBeauticationJob::Float64


    function BenchmarkData_WorkerCore(workerRank::Int)::BenchmarkData_WorkerCore
        new(
            workerRank, # Worker id
            0, # Number of occasions map data was not available and we had to wait
            #
            0, # Total Map Tiles Collected 
            0, # Tiles Explored 
            #
            0, # Seconds spent idle waiting for map data to come in 
            0, # Seconds between receiving job and having sent beautified paths in return
            #
            0, # Seconds spent waiting for the initial job and map data to come in
            0, # Number of times new map data was requested (should be minimized)
            #
            -99, # Start time
            -99, # Time of receiving initial job
            #
            -99, # Seconds from reciving initial job to having sent initial paths
            -99,
            #
            -99,
            -0, # Raw computation seconds, initial
            #
            -0, # Raw copmutation seconds, beautify
            0,
            #
            0, # Finishing initial job
            -99, # receiving beautification job
        )
    end
end






const BenchmarkValue_NOTSET = -999

mutable struct BenchmarkData_MasterCore
    mapName::String

    workerCount::Int
    totalMapSize::Int

    initialPathCost::Int
    beautifiedPathCost::Int

    firstWorkerIdToCompleteSecondInitialPath::Int # Necessary for beautification 
    lastWorkerIdToCompleteSecondInitialPath::Int # Necessary for beautification 

    secondsToSendInitialPathsAndJobsToAllWorkers::Float64
    secondsFromStartToHavingReceivedAllInitialPaths::Float64

    secondsFromStartToHavingReceivedAllBeautifiedPaths::Float64
    secondsForOfflinePreludeBeforeSendingInitialJobs::Float64

    startTime::Float64
    timesAMapSupplementWasRequested::Int

    initialMapDeliverySize::Int
    finalSize::Int

    finalLevel::Int
    numberOfTimesPriorityWorkerWasChosenForBeautification::Int


    function BenchmarkData_MasterCore(mapName::String, workerCount::Int, mapSize::Int, initialMapDeliverySize::Int)::BenchmarkData_MasterCore
        new(
            mapName,
            workerCount,
            mapSize,
            #
            BenchmarkValue_NOTSET, # initialPathCost
            BenchmarkValue_NOTSET, # beautifiedPathCost
            #
            BenchmarkValue_NOTSET, # firstWorkerIdToCompleteSecondInitialPath
            BenchmarkValue_NOTSET, # lastWorkerIdToCompleteSecondInitialPath
            #
            BenchmarkValue_NOTSET, # secondsToSendInitialPathsAndJobsToAllWorkers
            BenchmarkValue_NOTSET, # secondsFromStartToHavingReceivedAllInitialPaths 
            #
            BenchmarkValue_NOTSET, # secondsFromStartToHavingReceivedAllBeautifiedPaths
            BenchmarkValue_NOTSET, # secondsForOfflinePreludeBeforeSendingInitialJobs
            #
            BenchmarkValue_NOTSET, #startTime
            0, # timesAMapSupplementWasRequested
            #
            initialMapDeliverySize, # Initial map Delivery Size
            -99, # finalSize
            #
            -99, #final Level
            0,
        )
    end

end



mutable struct BestWorstAverage
    bestVal
    bestId

    worstVal
    worstId

    averageVal

    function BestWorstAverage(bestVal, bestId, worstVal, worstId, averageVal)
        new(bestVal, bestId, worstVal, worstId, averageVal)
    end


    function BestWorstAverage(vecOfValuesAndWorkerIdTuples)
        all = [(v[1], v[2]) for v in vecOfValuesAndWorkerIdTuples]
        worst = maximum(all)
        worstVal = worst[1]
        worstId = worst[2]

        best = minimum(all)
        bestVal = best[1]
        bestId = best[2]

        averageVal = mean(a[1] for a in all)
        new(bestVal, bestId, worstVal, worstId, averageVal)
    end
end

function BWA_Average(BWAs::Vector{BestWorstAverage})
    avg_averageVal = mean([b.averageVal for b in BWAs])
    avg_worstVal = mean([b.worstVal for b in BWAs])
    avg_worstId = round(Int, mean([b.worstId for b in BWAs]))

    avg_bestVal = mean([b.bestVal for b in BWAs])
    avg_bestId = round(Int, mean([b.bestId for b in BWAs]))

    BestWorstAverage(avg_bestVal, avg_bestId, avg_worstVal, avg_worstId, avg_averageVal)
end







# function OPT1_AverageMasterBenchmarkData(datas::Vector{BenchmarkData_MasterCore})
#     if length(datas) == 0
#         error("Tried to average a master benchmark vector of 0 elements")
#     end
#     if length(datas) == 1
#         return datas[1]
#     end

#     warmupDiscarded::Vector{BenchmarkData_MasterCore} = view(datas, 2:length(datas))
#     firstEntry::BenchmarkData_MasterCore = warmupDiscarded[1]

#     # Things that are constant
#     averaged = BenchmarkData_MasterCore(firstEntry.mapName, firstEntry.workerCount, firstEntry.totalMapSize, firstEntry.initialMapDeliverySize)

#     all_firstWorkerIdToCompleteSecondInitialPath::Vector{Float64} = [Float64(w.firstWorkerIdToCompleteSecondInitialPath) for w in warmupDiscarded]
#     averaged.firstWorkerIdToCompleteSecondInitialPath = Int(mean(all_firstWorkerIdToCompleteSecondInitialPath))

#     all_lastWorkerIdToCompleteSecondInitialPath::Vector{Float64} = [Float64(w.lastWorkerIdToCompleteSecondInitialPath) for w in warmupDiscarded]
#     averaged.lastWorkerIdToCompleteSecondInitialPath = Int(mean(all_lastWorkerIdToCompleteSecondInitialPath))
#     # TODO: The remaining values 

#     all_secondsToSendInitialPathsAndJobsToAllWorkers::Vector{Float64} = [Float64(w.secondsToSendInitialPathsAndJobsToAllWorkers) for w in warmupDiscarded]
#     averaged.secondsToSendInitialPathsAndJobsToAllWorkers = Float64(mean(all_secondsToSendInitialPathsAndJobsToAllWorkers))


# end



# the \ skips cancels a newline in the string
function OPT1_GenerateWorkerReport(workerData::BenchmarkData_WorkerCore)::String
    report::String = "
        +++WORKER REPORT FOR WORKER $(workerData.workerId)+++

        ---END OF REPORT FOR WORKER $(workerData.workerId)---
    "

    return report
end



struct OPT1_BenchmarkingReportStruct
    mapName
    workerCount

    totalMapSize
    equivalentWidthHeight

    initialPathCost
    beautifiedPathCost

    firstWorkerIdToCompleteSecondInitialPath
    lastWorkerIdToCompleteSecondInitialPath

    numberOfTimesNewMapDataWasRequested_BWA
    numberOfOccasionsMapDataWasNotAvailableAndIHadToWait_BWA

    secondsSpentWaitingForMapDataToComeIn_BWA
    secondsFromReceivingJobToHavingSentInitialPaths_BWA

    secondsFromReceivingJobToHavingSentBeautifiedPaths_BWA
    solvingBeautifiedPathAfterReceivingBeautificationJob_BWA

    waitingForBeautificationJobAfterSolvingInitial_BWA
    initialMapDeliverySize

    timesAMapSupplementWasRequested
    finalLevel

    finalSize
    secondsForOfflinePreludeBeforeSendingInitialJobs

    secondsToSendInitialPathsAndJobsToAllWorkers
    secondsFromStartToHavingReceivedAllInitialPaths

    secondsFromStartToHavingReceivedAllBeautifiedPaths
    rawComputationSeconds_Initial_BWA

    rawComputationSeconds_Beautify_BWA
    st_cost

    st_seconds
    numberOfBeautificationPathsSolved_BWA

    numberOfTimesPriorityWorkerWasChosenForBeautification
end

function OPT1_AverageBenchmarkingReportStructs(reportStructs::Vector{OPT1_BenchmarkingReportStruct})::OPT1_BenchmarkingReportStruct
    n = length(reportStructs)
    if n == 0
        error("reportStructs[] is empty")
    end

    first = reportStructs[1]

    return OPT1_BenchmarkingReportStruct(
        first.mapName,
        first.workerCount,
        #
        first.totalMapSize,
        first.equivalentWidthHeight,
        #
        round(Int, mean(r.initialPathCost for r in reportStructs)),
        round(Int, mean(r.beautifiedPathCost for r in reportStructs)),
        round(Int, mean(r.firstWorkerIdToCompleteSecondInitialPath for r in reportStructs)),
        round(Int, mean(r.lastWorkerIdToCompleteSecondInitialPath for r in reportStructs)),
        #
        BWA_Average([r.numberOfTimesNewMapDataWasRequested_BWA for r in reportStructs]),
        BWA_Average([r.numberOfOccasionsMapDataWasNotAvailableAndIHadToWait_BWA for r in reportStructs]),
        #
        BWA_Average([r.secondsSpentWaitingForMapDataToComeIn_BWA for r in reportStructs]),
        BWA_Average([r.secondsFromReceivingJobToHavingSentInitialPaths_BWA for r in reportStructs]),
        #
        BWA_Average([r.secondsFromReceivingJobToHavingSentBeautifiedPaths_BWA for r in reportStructs]),
        BWA_Average([r.solvingBeautifiedPathAfterReceivingBeautificationJob_BWA for r in reportStructs]),
        #
        BWA_Average([r.waitingForBeautificationJobAfterSolvingInitial_BWA for r in reportStructs]),
        round(Int, mean(r.initialMapDeliverySize for r in reportStructs)),
        #
        round(Int, mean(r.timesAMapSupplementWasRequested for r in reportStructs)),
        round(Int, mean(r.finalLevel for r in reportStructs)),
        #
        round(Int, mean(r.finalSize for r in reportStructs)),
        mean(r.secondsForOfflinePreludeBeforeSendingInitialJobs for r in reportStructs),
        #
        mean(r.secondsToSendInitialPathsAndJobsToAllWorkers for r in reportStructs),
        mean(r.secondsFromStartToHavingReceivedAllInitialPaths for r in reportStructs),
        #
        mean(r.secondsFromStartToHavingReceivedAllBeautifiedPaths for r in reportStructs),
        BWA_Average([r.rawComputationSeconds_Initial_BWA for r in reportStructs]),
        #
        BWA_Average([r.rawComputationSeconds_Beautify_BWA for r in reportStructs]),
        mean(r.st_cost for r in reportStructs),
        #
        mean(r.st_seconds for r in reportStructs),
        BWA_Average([r.numberOfBeautificationPathsSolved_BWA for r in reportStructs]),
        #
        mean(r.numberOfTimesPriorityWorkerWasChosenForBeautification for r in reportStructs)
    )
end



function OPT1_GenerateReportString(reportStruct::OPT1_BenchmarkingReportStruct)::String
    r = reportStruct
    percentageOfTimePriorityWorkerWasChosen = 100 / Float64(r.workerCount) * Float64(r.numberOfTimesPriorityWorkerWasChosenForBeautification)

    # First time I'm ever using reflection. Now I know why this is useful
    bottleneckExclusions = ["st_cost", "RandomMap", "numberOfTimesPriorityWorkerWasChosen",
        "numberOfTimesNewMapDataWasRequested", "numberOfBeautificationPathsSolved",
        "secondsFromReceivingJobToHavingSentBeautifiedPaths",
        "secondsFromStartToHavingReceivedAllInitialPaths",
        "secondsFromStartToHavingReceivedAllBeautifiedPaths",
        "st_seconds",]
    potentialBottlenecks = ""
    allFloatValues = Vector{Float64}()
    averageBottleneckValue = 0
    for fieldName in fieldnames(typeof(r))
        skip = false
        for exclusion in bottleneckExclusions
            if occursin(exclusion, string(fieldName))
                skip = true
                break
            end
        end
        if skip
            continue
        end

        fieldValue = getfield(r, fieldName)
        if fieldValue isa Float64
            push!(allFloatValues, fieldValue)
        elseif fieldValue isa BestWorstAverage
            push!(allFloatValues, fieldValue.bestVal)
            push!(allFloatValues, fieldValue.worstVal)
            push!(allFloatValues, fieldValue.averageVal)
        end
    end

    averageBottleneckValue = mean(allFloatValues)
    bottleneckThreshold = averageBottleneckValue

    for fieldName in fieldnames(typeof(r))
        skip = false
        for exclusion in bottleneckExclusions
            if occursin(exclusion, string(fieldName))
                skip = true
                break
            end
        end
        if skip
            continue
        end

        fieldValue = getfield(r, fieldName)
        if fieldValue isa Float64
            if fieldValue > bottleneckThreshold
                potentialBottlenecks *= "[bottleneck] $fieldName: $fieldValue\n"
            end
        elseif fieldValue isa BestWorstAverage
            for bwaFieldName in fieldnames(typeof(fieldValue))
                bwaValue = getfield(fieldValue, bwaFieldName)
                if bwaValue isa Float64
                    if bwaValue > bottleneckThreshold
                        potentialBottlenecks *= "[bottleneck] $fieldName:: $bwaFieldName: $bwaValue\n"
                    end
                end
            end

        end
    end


    # TODO: Total time not doing raw computation (summing waiting and non-waiting together)
    report::String = "
        +++MASTER REPORT FOR [$(r.mapName)] WITH $(r.workerCount) WORKERS+++

        | Map Info
        Total Map Size: $(r.totalMapSize) (Equivalent to a $(r.equivalentWidthHeight)x$(r.equivalentWidthHeight) map)

        | Path Cost
        Initial Path Cost: $(r.initialPathCost)
        Beautified Path Cost: $(r.beautifiedPathCost)
        Single threaded cost: $(r.st_cost)

        | Path generation time
        Seconds from start to having received all Initial Paths: $(r.secondsFromStartToHavingReceivedAllInitialPaths)
        Seconds from start to having received all Beautified Paths: $(r.secondsFromStartToHavingReceivedAllBeautifiedPaths)
        Seconds between having received all Initial Paths and all Beautified Paths: $(r.secondsFromStartToHavingReceivedAllBeautifiedPaths - r.secondsFromStartToHavingReceivedAllInitialPaths)
        Single threaded seconds: $(r.st_seconds)

        | Load Balance
        First worker to complete the second initial path: $(r.firstWorkerIdToCompleteSecondInitialPath)
        Last worker to complete the second initial path: $(r.lastWorkerIdToCompleteSecondInitialPath)

        | Occasions that new map data was requested
        Unlucky worker $(r.numberOfTimesNewMapDataWasRequested_BWA.worstId) had to request new map data $(r.numberOfTimesNewMapDataWasRequested_BWA.worstVal) times
        Lucky worker $(r.numberOfTimesNewMapDataWasRequested_BWA.bestId) had to request new map data $(r.numberOfTimesNewMapDataWasRequested_BWA.bestVal) times
        On average a worker had to request new map data $(r.numberOfTimesNewMapDataWasRequested_BWA.averageVal) times

        | Occasions having to wait for for new map data to come in
        Unlucky Worker $(r.numberOfOccasionsMapDataWasNotAvailableAndIHadToWait_BWA.worstId) had to wait $(r.numberOfOccasionsMapDataWasNotAvailableAndIHadToWait_BWA.worstVal) times when data was not available after request
        Lucky worker $(r.numberOfOccasionsMapDataWasNotAvailableAndIHadToWait_BWA.bestId) had to wait $(r.numberOfOccasionsMapDataWasNotAvailableAndIHadToWait_BWA.bestVal) times when data was not available after request
        On average a worker had to wait $(r.numberOfOccasionsMapDataWasNotAvailableAndIHadToWait_BWA.averageVal) times when data was not available after request

        | Seconds spent idle waiting for map data to come in, vs doing actual work
        Unlucky Worker $(r.secondsSpentWaitingForMapDataToComeIn_BWA.worstId) had to wait $(r.secondsSpentWaitingForMapDataToComeIn_BWA.worstVal) seconds for map data to come in
        Lucky Worker $(r.secondsSpentWaitingForMapDataToComeIn_BWA.bestId) had to wait $(r.secondsSpentWaitingForMapDataToComeIn_BWA.bestVal) seconds for map data to come in
        On average a worker had to wait for $(r.secondsSpentWaitingForMapDataToComeIn_BWA.averageVal) seconds for map data to come in

        | Raw computation on the initial paths
        Unlucky worker $(r.rawComputationSeconds_Initial_BWA.worstId) spent $(r.rawComputationSeconds_Initial_BWA.worstVal) seconds of raw computation time on the Initial pathfinding
        Lucky worker $(r.rawComputationSeconds_Initial_BWA.bestId) spent $(r.rawComputationSeconds_Initial_BWA.bestVal) seconds of raw computation time on the Initial pathfinding
        On average, a worker spent $(r.rawComputationSeconds_Initial_BWA.averageVal) seconds of raw computation time on Initial pathfindign

        | Raw computation on the beautify paths
        ~Unlucky~ worker $(r.rawComputationSeconds_Beautify_BWA.worstId) spent $(r.rawComputationSeconds_Beautify_BWA.worstVal) seconds of raw computation time on the Beautify pathfinding
        ~Lucky~ worker $(r.rawComputationSeconds_Beautify_BWA.bestId) spent $(r.rawComputationSeconds_Beautify_BWA.bestVal) seconds of raw computation time on the Beautify pathfinding
        On average, a worker spent $(r.rawComputationSeconds_Beautify_BWA.averageVal) seconds of raw computation time on beautify pathfindign

        | Number of beautification paths solved per worker
        ~Unlucky~ worker $(r.numberOfBeautificationPathsSolved_BWA.worstId) solved $(r.numberOfBeautificationPathsSolved_BWA.worstVal) beautification paths
        ~Lucky~ worker $(r.numberOfBeautificationPathsSolved_BWA.bestId) solved $(r.numberOfBeautificationPathsSolved_BWA.bestVal) beautification paths
        On average, a worker solved $(r.numberOfBeautificationPathsSolved_BWA.averageVal) beautification paths


        | Worker job completion: Initial paths
        Unlucky worker $(r.secondsFromReceivingJobToHavingSentInitialPaths_BWA.worstId) took $(r.secondsFromReceivingJobToHavingSentInitialPaths_BWA.worstVal) seconds to solve initial path after receiving job
        Lucky worker $(r.secondsFromReceivingJobToHavingSentInitialPaths_BWA.bestId) took $(r.secondsFromReceivingJobToHavingSentInitialPaths_BWA.bestVal) seconds to solve initial path after receiving job
        On average a worker spent $(r.secondsFromReceivingJobToHavingSentInitialPaths_BWA.averageVal) seconds to solve the initial path after receiving job 

        | Worker job completion: Beautified paths
        Unlucky worker $(r.secondsFromReceivingJobToHavingSentBeautifiedPaths_BWA.worstId) took $(r.secondsFromReceivingJobToHavingSentBeautifiedPaths_BWA.worstVal) seconds to solve Beautified path after receiving initial job
        Lucky worker $(r.secondsFromReceivingJobToHavingSentBeautifiedPaths_BWA.bestId) took $(r.secondsFromReceivingJobToHavingSentBeautifiedPaths_BWA.bestVal) seconds to solve Beautified path after receiving initial job
        On average a worker spent $(r.secondsFromReceivingJobToHavingSentBeautifiedPaths_BWA.averageVal) seconds to solve the Beautified path after receiving initial job 

        | Worker: Solving beautified path(s) after receiving first beautified path
        Unlucky worker $(r.solvingBeautifiedPathAfterReceivingBeautificationJob_BWA.worstId) took $(r.solvingBeautifiedPathAfterReceivingBeautificationJob_BWA.worstVal) seconds to solve beautified path after receiving beautification job
        Lucky worker $(r.solvingBeautifiedPathAfterReceivingBeautificationJob_BWA.bestId) took $(r.solvingBeautifiedPathAfterReceivingBeautificationJob_BWA.bestVal) seconds to solve beautified path after receiving beautification job
        On average, a worker spent $(r.solvingBeautifiedPathAfterReceivingBeautificationJob_BWA.averageVal) seconds to solve the beautification path after receiving the beautification job

        Unlucky worker $(r.waitingForBeautificationJobAfterSolvingInitial_BWA.worstId) spent $(r.waitingForBeautificationJobAfterSolvingInitial_BWA.worstVal) seconds waiting for beautification job after solving initial
        Lucky worker $(r.waitingForBeautificationJobAfterSolvingInitial_BWA.bestId) spent $(r.waitingForBeautificationJobAfterSolvingInitial_BWA.bestVal) seconds waiting for beautification job after solving initial
        On average, a worker spent $(r.waitingForBeautificationJobAfterSolvingInitial_BWA.averageVal) seconds waiting for beautification job after solving initial

        On average, a priority worker was chosen $(percentageOfTimePriorityWorkerWasChosen)% of the time.

        | Hyperparameter Configuration
        Initial map delivery size: $(r.initialMapDeliverySize)
        Number of times a map supplement was requested: $(r.timesAMapSupplementWasRequested)
        Final level for map supplements: $(r.finalLevel), with a size of $(r.finalSize)
        Again, the total map size is $(r.totalMapSize)


        | Master Overhead
        Seconds for offline prelude before sending initial jobs: $(r.secondsForOfflinePreludeBeforeSendingInitialJobs)
        Seconds to send initial paths and jobs to all workers: $(r.secondsToSendInitialPathsAndJobsToAllWorkers)

        | Potential bottlenecks
        $potentialBottlenecks

    "
end





function OPT1_GenerateBenchmarkReport(masterData::BenchmarkData_MasterCore, workerDatas::Vector{BenchmarkData_WorkerCore}, stCost, stSeconds)::OPT1_BenchmarkingReportStruct
    m::BenchmarkData_MasterCore = masterData
    equivalentWidthHeight::Int = Int(sqrt(m.totalMapSize))

    # Create tuples for each metric
    occasionsTuples = [(w.numberOfOccasionsMapDataWasNotAvailableAndIHadToWait, w.workerId) for w in workerDatas]
    occasions_BWA = BestWorstAverage(occasionsTuples)

    requestsTuples = [(w.numberOfTimesNewMapDataWasRequested, w.workerId) for w in workerDatas]
    requests_BWA = BestWorstAverage(requestsTuples)

    waitingTuples = [(w.secondsSpentWaitingForMapDataToComeIn, w.workerId) for w in workerDatas]
    waiting_BWA = BestWorstAverage(waitingTuples)

    initialJobTuples = [(w.secondsFromReceivingJobToHavingSentInitialPaths, w.workerId) for w in workerDatas]
    initialJob_BWA = BestWorstAverage(initialJobTuples)

    beautifiedJobTuples = [(w.secondsFromReceivingJobToHavingSentBeautifiedPaths, w.workerId) for w in workerDatas]
    beautifiedJob_BWA = BestWorstAverage(beautifiedJobTuples)

    solvingBeautifyTuples = [(w.solvingBeautifiedPathAfterReceivingBeautificationJob, w.workerId) for w in workerDatas if w.timeOfReceivingBeauticationJob > -1]
    solvingBeautify_BWA = BestWorstAverage(solvingBeautifyTuples)

    waitingBeautifyTuples = [(w.waitingForBeautificationJobAfterSolvingInitial, w.workerId) for w in workerDatas if w.waitingForBeautificationJobAfterSolvingInitial > -1]
    waitingBeautify_BWA = BestWorstAverage(waitingBeautifyTuples)

    rawInitialTuples = [(w.rawComputationSeconds_Initial, w.workerId) for w in workerDatas]
    rawInitial_BWA = BestWorstAverage(rawInitialTuples)

    rawBeautifyTuples = [(w.rawComputationSeconds_Beautify, w.workerId) for w in workerDatas]
    rawBeautify_BWA = BestWorstAverage(rawBeautifyTuples)

    beautificationPathsSolvedTuples = [(w.numberOfBeautificationJobsCompleted, w.workerId) for w in workerDatas]
    beautificationPathsSolved_BWA = BestWorstAverage(beautificationPathsSolvedTuples)

    reportStruct = OPT1_BenchmarkingReportStruct(
        m.mapName,
        m.workerCount,
        #
        m.totalMapSize,
        equivalentWidthHeight,
        #
        m.initialPathCost,
        m.beautifiedPathCost,
        #
        m.firstWorkerIdToCompleteSecondInitialPath,
        m.lastWorkerIdToCompleteSecondInitialPath,
        #
        requests_BWA,
        occasions_BWA,
        #
        waiting_BWA,
        initialJob_BWA,
        #
        beautifiedJob_BWA,
        solvingBeautify_BWA,
        #
        waitingBeautify_BWA,
        m.initialMapDeliverySize,
        #
        m.timesAMapSupplementWasRequested,
        m.finalLevel,
        #
        m.finalSize,
        m.secondsForOfflinePreludeBeforeSendingInitialJobs,
        #
        m.secondsToSendInitialPathsAndJobsToAllWorkers,
        m.secondsFromStartToHavingReceivedAllInitialPaths,
        #
        m.secondsFromStartToHavingReceivedAllBeautifiedPaths,
        rawInitial_BWA,
        #
        rawBeautify_BWA,
        stCost,
        #
        stSeconds,
        beautificationPathsSolved_BWA,
        #
        m.numberOfTimesPriorityWorkerWasChosenForBeautification
    )

    return reportStruct
end







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

