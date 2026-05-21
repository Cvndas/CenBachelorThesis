using Statistics


function HelloWorldFromBenchmarking()
    println("Hello world from Benchmarking!")
end






mutable struct mBenchmarkData_WorkerCore
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


    function mBenchmarkData_WorkerCore(workerRank::Int)::mBenchmarkData_WorkerCore
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
        )
    end

    # This is an empty constructor, intended as a buffer for the master to receive the incoming data over MPI
    function mBenchmarkData_WorkerCore()::mBenchmarkData_WorkerCore
        new(
            -77,
            #
            -77,
            -77,
            #
            -77,
            -77,
            #
            -77,
            -77,
            #
            -77,
            -77,
            #
            -77,
            -77,
            #
            -77,
            -77,
            #
            -77,
        )
    end
end


function mBenchmarkData_WorkerCore_MakeMPICompatbible(mutableVer::mBenchmarkData_WorkerCore)::BenchmarkData_WorkerCore
    m::mBenchmarkData_WorkerCore = mutableVer
    return BenchmarkData_WorkerCore(
        m.workerId,
        m.numberOfOccasionsMapDataWasNotAvailableAndIHadToWait,
        m.totalMapTilesCollected,
        m.tilesExplored,
        m.secondsSpentWaitingForMapDataToComeIn,
        m.secondsFromReceivingJobToHavingSentBeautifiedPaths,
        m.secondsWaitingForInitialJobAndMapDataToComeIn,
        m.numberOfTimesNewMapDataWasRequested,
        m.secondsFromReceivingJobToHavingSentInitialPaths,
        m.solvingBeautifiedPathAfterReceivingBeautificationJob,
        m.waitingForBeautificationJobAfterSolvingInitial,
        m.rawComputationSeconds_Initial,
        m.rawComputationSeconds_Beautify,
    )
end


struct BenchmarkData_WorkerCore
    workerId::Int # WorkerId is workerRank - 1
    numberOfOccasionsMapDataWasNotAvailableAndIHadToWait::Int

    totalMapTilesCollected::Int
    tilesExplored::Int

    secondsSpentWaitingForMapDataToComeIn::Float64
    secondsFromReceivingJobToHavingSentBeautifiedPaths::Float64

    secondsWaitingForInitialJobAndMapDataToComeIn::Float64
    numberOfTimesNewMapDataWasRequested::Int

    secondsFromReceivingJobToHavingSentInitialPaths::Float64
    solvingBeautifiedPathAfterReceivingBeautificationJob::Float64

    waitingForBeautificationJobAfterSolvingInitial::Float64
    rawComputationSeconds_Initial::Float64
    rawComputationSeconds_Beautify::Float64
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
        )
    end

end









# function OPT1_WorstWorkerBenchmarkData(datas::Vector{BenchmarkData_WorkerCore})
#     if length(datas) == 1
#         return datas[1]
#     end
#     worstBenchmark = mBenchmarkData_WorkerCore(-99)

#     error("Unfinished func")
# end

# function OPT1_AverageWorkerBenchmarkData(datas::Vector{BenchmarkData_WorkerCore})::BenchmarkData_WorkerCore
#     if length(datas) == 1
#         return datas[1]
#     end

#     averageBenchmark = mBenchmarkData_WorkerCore(-99)

#     error("Unfinished func")
# end


function OPT1_AverageMasterBenchmarkData(datas::Vector{BenchmarkData_MasterCore})
    if length(datas) == 0
        error("Tried to average a master benchmark vector of 0 elements")
    end
    if length(datas) == 1
        return datas[1]
    end

    warmupDiscarded::Vector{BenchmarkData_MasterCore} = view(datas, 2:length(datas))
    firstEntry::BenchmarkData_MasterCore = warmupDiscarded[1]

    # Things that are constant
    averaged = BenchmarkData_MasterCore(firstEntry.mapName, firstEntry.workerCount, firstEntry.totalMapSize, firstEntry.initialMapDeliverySize)

    all_firstWorkerIdToCompleteSecondInitialPath::Vector{Float64} = [Float64(w.firstWorkerIdToCompleteSecondInitialPath) for w in warmupDiscarded]
    averaged.firstWorkerIdToCompleteSecondInitialPath = Int(mean(all_firstWorkerIdToCompleteSecondInitialPath))

    all_lastWorkerIdToCompleteSecondInitialPath::Vector{Float64} = [Float64(w.lastWorkerIdToCompleteSecondInitialPath) for w in warmupDiscarded]
    averaged.lastWorkerIdToCompleteSecondInitialPath = Int(mean(all_lastWorkerIdToCompleteSecondInitialPath))
    # TODO: The remaining values 


end



# the \ skips cancels a newline in the string
function OPT1_GenerateWorkerReport(workerData::mBenchmarkData_WorkerCore)::String
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

    worst_numberOfTimesNewMapDataWasRequested
    best_numberOfTimesNewMapDataWasRequested
    average_numberOfTimesNewMapDataWasRequested

    worst_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait
    best_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait
    average_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait

    worst_secondsSpentWaitingForMapDataToComeIn
    best_secondsSpentWaitingForMapDataToComeIn
    average_secondsSpentWaitingForMapDataToComeIn

    worst_secondsFromReceivingJobToHavingSentInitialPaths
    best_secondsFromReceivingJobToHavingSentInitialPaths
    average_secondsFromReceivingJobToHavingSentInitialPaths

    worst_secondsFromReceivingJobToHavingSentBeautifiedPaths
    best_secondsFromReceivingJobToHavingSentBeautifiedPaths
    average_secondsFromReceivingJobToHavingSentBeautifiedPaths

    worst_solvingBeautifiedPathAfterReceivingBeautificationJob
    best_solvingBeautifiedPathAfterReceivingBeautificationJob
    average_solvingBeautifiedPathAfterReceivingBeautificationJob

    worst_waitingForBeautificationJobAfterSolvingInitial
    best_waitingForBeautificationJobAfterSolvingInitial
    average_waitingForBeautificationJobAfterSolvingInitial

    initialMapDeliverySize
    timesAMapSupplementWasRequested
    finalLevel
    finalSize

    secondsForOfflinePreludeBeforeSendingInitialJobs
    secondsToSendInitialPathsAndJobsToAllWorkers

    secondsFromStartToHavingReceivedAllInitialPaths
    secondsFromStartToHavingReceivedAllBeautifiedPaths

    worst_rawComputationSeconds_Initial
    best_rawComputationSeconds_Initial
    average_rawComputationSeconds_Initial

    worst_rawComputationSeconds_Beautify
    best_rawComputationSeconds_Beautify
    average_rawComputationSeconds_Beautify

    st_cost
    st_seconds
end



# Proompted with deepseek. I'm tired of doing these conversions
function OPT1_AverageBenchmarkingReportStructs(reportStructs::Vector{OPT1_BenchmarkingReportStruct})::OPT1_BenchmarkingReportStruct
    n = length(reportStructs)
    if n == 0
        error("reportStructs[] is empty")
    end

    first = reportStructs[1]

    return OPT1_BenchmarkingReportStruct(
        first.mapName,
        first.workerCount,
        first.totalMapSize,
        first.equivalentWidthHeight,

        # Simple numeric fields
        round(Int, mean(r.initialPathCost for r in reportStructs)),
        round(Int, mean(r.beautifiedPathCost for r in reportStructs)),
        round(Int, mean(r.firstWorkerIdToCompleteSecondInitialPath for r in reportStructs)),
        round(Int, mean(r.lastWorkerIdToCompleteSecondInitialPath for r in reportStructs)),
        #
        # Tuple fields - average both the value and the workerId
        (round(Int, mean(r.worst_numberOfTimesNewMapDataWasRequested[1] for r in reportStructs)),
            round(Int, mean(r.worst_numberOfTimesNewMapDataWasRequested[2] for r in reportStructs))),
        #
        (round(Int, mean(r.best_numberOfTimesNewMapDataWasRequested[1] for r in reportStructs)),
            round(Int, mean(r.best_numberOfTimesNewMapDataWasRequested[2] for r in reportStructs))),
        #
        mean(r.average_numberOfTimesNewMapDataWasRequested for r in reportStructs),
        #
        (round(Int, mean(r.worst_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait[1] for r in reportStructs)),
            round(Int, mean(r.worst_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait[2] for r in reportStructs))),
        #
        (round(Int, mean(r.best_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait[1] for r in reportStructs)),
            round(Int, mean(r.best_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait[2] for r in reportStructs))),
        #
        mean(r.average_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait for r in reportStructs),
        #
        (mean(r.worst_secondsSpentWaitingForMapDataToComeIn[1] for r in reportStructs),
            round(Int, mean(r.worst_secondsSpentWaitingForMapDataToComeIn[2] for r in reportStructs))),
        #
        (mean(r.best_secondsSpentWaitingForMapDataToComeIn[1] for r in reportStructs),
            round(Int, mean(r.best_secondsSpentWaitingForMapDataToComeIn[2] for r in reportStructs))),
        #
        mean(r.average_secondsSpentWaitingForMapDataToComeIn for r in reportStructs),
        #
        (mean(r.worst_secondsFromReceivingJobToHavingSentInitialPaths[1] for r in reportStructs),
            round(Int, mean(r.worst_secondsFromReceivingJobToHavingSentInitialPaths[2] for r in reportStructs))),
        #
        (mean(r.best_secondsFromReceivingJobToHavingSentInitialPaths[1] for r in reportStructs),
            round(Int, mean(r.best_secondsFromReceivingJobToHavingSentInitialPaths[2] for r in reportStructs))),
        #
        mean(r.average_secondsFromReceivingJobToHavingSentInitialPaths for r in reportStructs),
        #
        (mean(r.worst_secondsFromReceivingJobToHavingSentBeautifiedPaths[1] for r in reportStructs),
            round(Int, mean(r.worst_secondsFromReceivingJobToHavingSentBeautifiedPaths[2] for r in reportStructs))),
        #
        (mean(r.best_secondsFromReceivingJobToHavingSentBeautifiedPaths[1] for r in reportStructs),
            round(Int, mean(r.best_secondsFromReceivingJobToHavingSentBeautifiedPaths[2] for r in reportStructs))),
        #
        mean(r.average_secondsFromReceivingJobToHavingSentBeautifiedPaths for r in reportStructs),
        #
        (mean(r.worst_solvingBeautifiedPathAfterReceivingBeautificationJob[1] for r in reportStructs),
            round(Int, mean(r.worst_solvingBeautifiedPathAfterReceivingBeautificationJob[2] for r in reportStructs))),
        #
        (mean(r.best_solvingBeautifiedPathAfterReceivingBeautificationJob[1] for r in reportStructs),
            round(Int, mean(r.best_solvingBeautifiedPathAfterReceivingBeautificationJob[2] for r in reportStructs))),
        #
        mean(r.average_solvingBeautifiedPathAfterReceivingBeautificationJob for r in reportStructs),
        #
        (mean(r.worst_waitingForBeautificationJobAfterSolvingInitial[1] for r in reportStructs),
            round(Int, mean(r.worst_waitingForBeautificationJobAfterSolvingInitial[2] for r in reportStructs))),
        #
        (mean(r.best_waitingForBeautificationJobAfterSolvingInitial[1] for r in reportStructs),
            round(Int, mean(r.best_waitingForBeautificationJobAfterSolvingInitial[2] for r in reportStructs))),
        #
        mean(r.average_waitingForBeautificationJobAfterSolvingInitial for r in reportStructs),
        #
        round(Int, mean(r.initialMapDeliverySize for r in reportStructs)),
        round(Int, mean(r.timesAMapSupplementWasRequested for r in reportStructs)),
        round(Int, mean(r.finalLevel for r in reportStructs)),
        round(Int, mean(r.finalSize for r in reportStructs)),
        mean(r.secondsForOfflinePreludeBeforeSendingInitialJobs for r in reportStructs),
        mean(r.secondsToSendInitialPathsAndJobsToAllWorkers for r in reportStructs),
        mean(r.secondsFromStartToHavingReceivedAllInitialPaths for r in reportStructs),
        mean(r.secondsFromStartToHavingReceivedAllBeautifiedPaths for r in reportStructs),
        #
        (mean(r.worst_rawComputationSeconds_Initial[1] for r in reportStructs),
            round(Int, mean(r.worst_rawComputationSeconds_Initial[2] for r in reportStructs))),
        #
        (mean(r.best_rawComputationSeconds_Initial[1] for r in reportStructs),
            round(Int, mean(r.best_rawComputationSeconds_Initial[2] for r in reportStructs))),
        #
        mean(r.average_rawComputationSeconds_Initial for r in reportStructs),
        #
        (mean(r.worst_rawComputationSeconds_Beautify[1] for r in reportStructs),
            round(Int, mean(r.worst_rawComputationSeconds_Beautify[2] for r in reportStructs))),
        #
        (mean(r.best_rawComputationSeconds_Beautify[1] for r in reportStructs),
            round(Int, mean(r.best_rawComputationSeconds_Beautify[2] for r in reportStructs))),
        #
        mean(r.average_rawComputationSeconds_Beautify for r in reportStructs),
        #
        mean(r.st_cost for r in reportStructs),
        mean(r.st_seconds for r in reportStructs)
    )
end


function OPT1_GenerateReportString(reportStruct::OPT1_BenchmarkingReportStruct)::String
    r = reportStruct
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
        Unlucky worker $(r.worst_numberOfTimesNewMapDataWasRequested[2]) had to request new map data $(r.worst_numberOfTimesNewMapDataWasRequested[1]) times
        Lucky worker $(r.best_numberOfTimesNewMapDataWasRequested[2]) had to request new map data $(r.best_numberOfTimesNewMapDataWasRequested[1]) times
        On average a worker had to request new map data $(r.average_numberOfTimesNewMapDataWasRequested) times

        | Occasions having to wait for for new map data to come in
        Unlucky Worker $(r.worst_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait[2]) had to wait $(r.worst_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait[1]) times when data was not available after request
        Lucky worker $(r.best_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait[2]) had to wait $(r.best_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait[1]) times when data was not available after request
        On average a worker had to wait $(r.average_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait) times when data was not available after request

        | Seconds spent idle waiting for map data to come in, vs doing actual work
        Unlucky Worker $(r.worst_secondsSpentWaitingForMapDataToComeIn[2]) had to wait $(r.worst_secondsSpentWaitingForMapDataToComeIn[1]) seconds for map data to come in
        Lucky Worker $(r.best_secondsSpentWaitingForMapDataToComeIn[2]) had to wait $(r.best_secondsSpentWaitingForMapDataToComeIn[1]) seconds for map data to come in
        On average a worker had to wait for $(r.average_secondsSpentWaitingForMapDataToComeIn) seconds for map data to come in

        Unlucky worker $(r.worst_rawComputationSeconds_Initial[2]) spent $(r.worst_rawComputationSeconds_Initial[1]) seconds of raw computation time on the Initial pathfinding
        Lucky worker $(r.best_rawComputationSeconds_Initial[2]) spent $(r.best_rawComputationSeconds_Initial[1]) seconds of raw computation time on the Initial pathfinding
        On average, a worker spent $(r.average_rawComputationSeconds_Initial) seconds of raw computation time on Initial pathfindign

        Unlucky worker $(r.worst_rawComputationSeconds_Beautify[2]) spent $(r.worst_rawComputationSeconds_Beautify[1]) seconds of raw computation time on the Beautify pathfinding
        Lucky worker $(r.best_rawComputationSeconds_Beautify[2]) spent $(r.best_rawComputationSeconds_Beautify[1]) seconds of raw computation time on the Beautify pathfinding
        On average, a worker spent $(r.average_rawComputationSeconds_Beautify) seconds of raw computation time on beautify pathfindign


        | Worker job completion: Initial paths
        Unlucky worker $(r.worst_secondsFromReceivingJobToHavingSentInitialPaths[2]) took $(r.worst_secondsFromReceivingJobToHavingSentInitialPaths[1]) seconds to solve initial path after receiving job
        Lucky worker $(r.best_secondsFromReceivingJobToHavingSentInitialPaths[2]) took $(r.best_secondsFromReceivingJobToHavingSentInitialPaths[1]) seconds to solve initial path after receiving job
        On average a worker spent $(r.average_secondsFromReceivingJobToHavingSentInitialPaths) seconds to solve the initial path after receiving job 

        | Worker job completion: Beautified paths
        Unlucky worker $(r.worst_secondsFromReceivingJobToHavingSentBeautifiedPaths[2]) took $(r.worst_secondsFromReceivingJobToHavingSentBeautifiedPaths[1]) seconds to solve Beautified path after receiving initial job
        Lucky worker $(r.best_secondsFromReceivingJobToHavingSentBeautifiedPaths[2]) took $(r.best_secondsFromReceivingJobToHavingSentBeautifiedPaths[1]) seconds to solve Beautified path after receiving initial job
        On average a worker spent $(r.average_secondsFromReceivingJobToHavingSentBeautifiedPaths) seconds to solve the Beautified path after receiving initial job 

        Unlucky worker $(r.worst_solvingBeautifiedPathAfterReceivingBeautificationJob[2]) took $(r.worst_solvingBeautifiedPathAfterReceivingBeautificationJob[1]) seconds to solve beautified path after receiving beautification job
        Lucky worker $(r.best_solvingBeautifiedPathAfterReceivingBeautificationJob[2]) took $(r.best_solvingBeautifiedPathAfterReceivingBeautificationJob[1]) seconds to solve beautified path after receiving beautification job
        On average, a worker spent $(r.average_solvingBeautifiedPathAfterReceivingBeautificationJob) seconds to solve the beautification path after receiving the beautification job

        Unlucky worker $(r.worst_waitingForBeautificationJobAfterSolvingInitial[2]) spent $(r.worst_waitingForBeautificationJobAfterSolvingInitial[1]) seconds waiting for beautification job after solving initial
        Lucky worker $(r.best_waitingForBeautificationJobAfterSolvingInitial[2]) spent $(r.best_waitingForBeautificationJobAfterSolvingInitial[1]) seconds waiting for beautification job after solving initial
        On average, a worker spent $(r.average_waitingForBeautificationJobAfterSolvingInitial) seconds waiting for beautification job after solving initial



        | Hyperparameter Configuration
        Initial map delivery size: $(r.initialMapDeliverySize)
        Number of times a map supplement was requested: $(r.timesAMapSupplementWasRequested)
        Final level for map supplements: $(r.finalLevel), with a size of $(r.finalSize)
        Again, the total map size is $(r.totalMapSize)


        | Master Overhead
        Seconds for offline prelude before sending initial jobs: $(r.secondsForOfflinePreludeBeforeSendingInitialJobs)
        Seconds to send initial paths and jobs to all workers: $(r.secondsToSendInitialPathsAndJobsToAllWorkers)

    "
end



function OPT1_GenerateBenchmarkReport(masterData::BenchmarkData_MasterCore, workerDatas::Vector{BenchmarkData_WorkerCore}, stCost, stSeconds)::OPT1_BenchmarkingReportStruct
    # TODO: Along with the string, return a struct that has the comprehensive data, so that the comprehensive data can be averaged,
    # including the worker data of multiple runs. Everything I print here, also store it in a struct.
    # Basically, make a maze solve return exactly one benchmark report, which also contains information
    # about the workers.
    m::BenchmarkData_MasterCore = masterData
    equivalentWidthHeight::Int = Int(sqrt(m.totalMapSize))

    all_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait = [(w.numberOfOccasionsMapDataWasNotAvailableAndIHadToWait, w.workerId) for w in workerDatas]
    worst_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait = maximum(all_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait)
    best_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait = minimum(all_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait)
    average_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait = mean(t[1] for t in all_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait)

    all_numberOfTimesNewMapDataWasRequested = [(w.numberOfTimesNewMapDataWasRequested, w.workerId) for w in workerDatas]
    worst_numberOfTimesNewMapDataWasRequested = maximum(all_numberOfTimesNewMapDataWasRequested)
    best_numberOfTimesNewMapDataWasRequested = minimum(all_numberOfTimesNewMapDataWasRequested)
    average_numberOfTimesNewMapDataWasRequested = mean(t[1] for t in all_numberOfTimesNewMapDataWasRequested)

    all_secondsSpentWaitingForMapDataToComeIn = [(w.secondsSpentWaitingForMapDataToComeIn, w.workerId) for w in workerDatas]
    worst_secondsSpentWaitingForMapDataToComeIn = maximum(all_secondsSpentWaitingForMapDataToComeIn)
    best_secondsSpentWaitingForMapDataToComeIn = minimum(all_secondsSpentWaitingForMapDataToComeIn)
    average_secondsSpentWaitingForMapDataToComeIn = mean(t[1] for t in all_secondsSpentWaitingForMapDataToComeIn)

    all_secondsFromReceivingJobToHavingSentInitialPaths = [(w.secondsFromReceivingJobToHavingSentInitialPaths, w.workerId) for w in workerDatas]
    worst_secondsFromReceivingJobToHavingSentInitialPaths = maximum(all_secondsFromReceivingJobToHavingSentInitialPaths)
    best_secondsFromReceivingJobToHavingSentInitialPaths = minimum(all_secondsFromReceivingJobToHavingSentInitialPaths)
    average_secondsFromReceivingJobToHavingSentInitialPaths = mean(t[1] for t in all_secondsFromReceivingJobToHavingSentInitialPaths)

    all_secondsFromReceivingJobToHavingSentBeautifiedPaths = [(w.secondsFromReceivingJobToHavingSentBeautifiedPaths, w.workerId) for w in workerDatas]
    worst_secondsFromReceivingJobToHavingSentBeautifiedPaths = maximum(all_secondsFromReceivingJobToHavingSentBeautifiedPaths)
    best_secondsFromReceivingJobToHavingSentBeautifiedPaths = minimum(all_secondsFromReceivingJobToHavingSentBeautifiedPaths)
    average_secondsFromReceivingJobToHavingSentBeautifiedPaths = mean(t[1] for t in all_secondsFromReceivingJobToHavingSentBeautifiedPaths)

    all_solvingBeautifiedPathAfterReceivingBeautificationJob = [(w.solvingBeautifiedPathAfterReceivingBeautificationJob, w.workerId) for w in workerDatas]
    worst_solvingBeautifiedPathAfterReceivingBeautificationJob = maximum(all_solvingBeautifiedPathAfterReceivingBeautificationJob)
    best_solvingBeautifiedPathAfterReceivingBeautificationJob = minimum(all_solvingBeautifiedPathAfterReceivingBeautificationJob)
    average_solvingBeautifiedPathAfterReceivingBeautificationJob = mean(t[1] for t in all_solvingBeautifiedPathAfterReceivingBeautificationJob)

    all_waitingForBeautificationJobAfterSolvingInitial = [(w.waitingForBeautificationJobAfterSolvingInitial, w.workerId) for w in workerDatas]
    worst_waitingForBeautificationJobAfterSolvingInitial = maximum(all_waitingForBeautificationJobAfterSolvingInitial)
    best_waitingForBeautificationJobAfterSolvingInitial = minimum(all_waitingForBeautificationJobAfterSolvingInitial)
    average_waitingForBeautificationJobAfterSolvingInitial = mean(t[1] for t in all_waitingForBeautificationJobAfterSolvingInitial)

    all_rawComputationseconds_Initial = [(w.rawComputationSeconds_Initial, w.workerId) for w in workerDatas]
    worst_rawComputationSeconds_Initial = maximum(all_rawComputationseconds_Initial)
    best_rawComputationSeconds_Initial = minimum(all_rawComputationseconds_Initial)
    average_rawComputationSeconds_Initial = mean(t[1] for t in all_rawComputationseconds_Initial)

    all_rawComputationseconds_Beautify = [(w.rawComputationSeconds_Beautify, w.workerId) for w in workerDatas]
    worst_rawComputationSeconds_Beautify = maximum(all_rawComputationseconds_Beautify)
    best_rawComputationSeconds_Beautify = minimum(all_rawComputationseconds_Beautify)
    average_rawComputationSeconds_Beautify = mean(t[1] for t in all_rawComputationseconds_Beautify)

    reportStruct = OPT1_BenchmarkingReportStruct(
        m.mapName,
        m.workerCount,
        m.totalMapSize,
        equivalentWidthHeight,
        m.initialPathCost,
        m.beautifiedPathCost,
        m.firstWorkerIdToCompleteSecondInitialPath,
        m.lastWorkerIdToCompleteSecondInitialPath,
        worst_numberOfTimesNewMapDataWasRequested,
        best_numberOfTimesNewMapDataWasRequested,
        average_numberOfTimesNewMapDataWasRequested,
        worst_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait,
        best_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait,
        average_numberOfOccasionsMapDataWasNotAvailableAndIHadToWait,
        worst_secondsSpentWaitingForMapDataToComeIn,
        best_secondsSpentWaitingForMapDataToComeIn,
        average_secondsSpentWaitingForMapDataToComeIn,
        worst_secondsFromReceivingJobToHavingSentInitialPaths,
        best_secondsFromReceivingJobToHavingSentInitialPaths,
        average_secondsFromReceivingJobToHavingSentInitialPaths,
        worst_secondsFromReceivingJobToHavingSentBeautifiedPaths,
        best_secondsFromReceivingJobToHavingSentBeautifiedPaths,
        average_secondsFromReceivingJobToHavingSentBeautifiedPaths,
        worst_solvingBeautifiedPathAfterReceivingBeautificationJob,
        best_solvingBeautifiedPathAfterReceivingBeautificationJob,
        average_solvingBeautifiedPathAfterReceivingBeautificationJob,
        worst_waitingForBeautificationJobAfterSolvingInitial,
        best_waitingForBeautificationJobAfterSolvingInitial,
        average_waitingForBeautificationJobAfterSolvingInitial,
        m.initialMapDeliverySize,
        m.timesAMapSupplementWasRequested,
        m.finalLevel,
        m.finalSize,
        m.secondsForOfflinePreludeBeforeSendingInitialJobs,
        m.secondsToSendInitialPathsAndJobsToAllWorkers,
        m.secondsFromStartToHavingReceivedAllInitialPaths,
        m.secondsFromStartToHavingReceivedAllBeautifiedPaths,
        worst_rawComputationSeconds_Initial,
        best_rawComputationSeconds_Initial,
        average_rawComputationSeconds_Initial,
        worst_rawComputationSeconds_Beautify,
        best_rawComputationSeconds_Beautify,
        average_rawComputationSeconds_Beautify,
        stCost,
        stSeconds,
    )


    return reportStruct
end

function GenerateBenchmarkReport_SingleThreaded

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


function ProduceGraph_totalTime(reportStructs::Vector{OPT1_BenchmarkingReportStruct}, fig, row, column)
    axis = Axis(fig[row, column])
    axis.aspect = DataAspect() # Makes the y and x axis scaled equally.
    points = []


    return axis
end


function ProduceGraph_pathCost(reportStructs::Vector{OPT1_BenchmarkingReportStruct}, fig, row, column)

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

    axis = Axis(
        fig[row, column],
        xlabel="Processor Count",
        ylabel="Path Cost",
        title="$(reportStructs[1].mapName): Path Cost and Processor Count",
        xticks=xTicks
    )
    # axis.aspect = DataAspect() # Makes the y and x axis scaled equally.

    # Right now there's some duplication: each report struct for this map has the st seconds and cost, each computed
    # by hand. Obviously not necessary. Will resolve that later TODO

    # x: core count, y: path cost

    stCost = reportStructs[1].st_cost

    sortedReportStruct = sort(reportStructs, by=x -> x.workerCount)

    initialPoints = [(1, stCost)]
    beautyPoints = [(1, stCost)]

    for reportStruct::OPT1_BenchmarkingReportStruct in sortedReportStruct
        initialPoint = (reportStruct.workerCount + 1, reportStruct.initialPathCost)
        beautyPoint = (reportStruct.workerCount + 1, reportStruct.beautifiedPathCost)
        push!(initialPoints, initialPoint)
        push!(beautyPoints, beautyPoint)
    end

    initialXs = [i[1] for i in initialPoints]
    beautyXs = [b[1] for b in beautyPoints]

    initialYs = [i[2] for i in initialPoints]
    beautyYs = [b[2] for b in beautyPoints]

    lines!(axis, initialXs, initialYs, color=:red, label="Initial Path Cost")
    lines!(axis, beautyXs, beautyYs, color=:green, label="Beautified Path Cost")

    legend = axislegend(
        "Path cost",
        position=:rb
    )

    return axis
end

mutable struct FilesForMap
    mapName::String
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
            error("File $file was not a file somehow")
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

    fig = Figure(; size=(1600, 900))
    currentColumn = 1
    for key in keys(mapNameAndFiles)
        println("There are $(length(mapNameAndFiles[key])) entries for map $(key)")

        # For every map:

        # First row: Time to complete
        push!(graphAxes, ProduceGraph_totalTime(mapNameAndFiles[key], fig, 1, currentColumn))

        # Second row: Path cost
        push!(graphAxes, ProduceGraph_pathCost(mapNameAndFiles[key], fig, 2, currentColumn))

        currentColumn += 1
    end


    # First row: totalTime, maps on the horizontal

    # Second row: Map Cost, maps on the horizontal

    display(fig)
    println("Press enter to Exit!")
    readline()
    GLMakie.closeall()
    println("Exiting...")
end

