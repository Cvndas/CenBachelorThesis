using Statistics


function HelloWorldFromBenchmarking()
    println("Hello world from Benchmarking!")
end






mutable struct BenchmarkData_WorkerCore
    workerId::Int # WorkerId is workerRank - 1
    numberOfOccasionsMapDataWasNotAvailableAndIHadToWait::Int #TODO

    totalMapTilesCollected::Int #TODO
    tilesExplored::Int #TODO

    secondsSpentWaitingForMapDataToComeIn::Float64 #TODO
    secondsFromReceivingJobToHavingSentBeautifiedPaths::Float64 #TODO

    secondsWaitingForInitialJobAndMapDataToComeIn::Float64 #TODO
    numberOfTimesNewMapDataWasRequested::Int #TODO


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
        )
    end

    # This is an empty constructor, intended as a buffer for the master to receive the incoming data over MPI
    function BenchmarkData_WorkerCore()::BenchmarkData_WorkerCore
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
        )
    end
end


function BenchmarkData_WorkerCore_MakeMPICompatbible(mutableVer::BenchmarkData_WorkerCore)::MpiCompatible_BenchmarkData_WorkerCore
    m::BenchmarkData_WorkerCore = mutableVer
    return MpiCompatible_BenchmarkData_WorkerCore(
        m.workerId,
        m.numberOfOccasionsMapDataWasNotAvailableAndIHadToWait,
        m.totalMapTilesCollected,
        m.tilesExplored,
        m.secondsSpentWaitingForMapDataToComeIn,
        m.secondsFromReceivingJobToHavingSentBeautifiedPaths,
        m.secondsWaitingForInitialJobAndMapDataToComeIn,
        m.numberOfTimesNewMapDataWasRequested
    )
end


struct MpiCompatible_BenchmarkData_WorkerCore
    workerId::Int # WorkerId is workerRank - 1
    numberOfOccasionsMapDataWasNotAvailableAndIHadToWait::Int #TODO

    totalMapTilesCollected::Int #TODO
    tilesExplored::Int #TODO

    secondsSpentWaitingForMapDataToComeIn::Float64 #TODO
    secondsFromReceivingJobToHavingSentBeautifiedPaths::Float64 #TODO

    secondsWaitingForInitialJobAndMapDataToComeIn::Float64 #TODO
    numberOfTimesNewMapDataWasRequested::Int #TODO
end



const BenchmarkValue_NOTSET = -999

mutable struct BenchmarkData_MasterCore
    mapName::String

    workerCount::Int
    totalMapSize::Int #TODO

    initialPathCost::Int #TODO
    beautifiedPathCost::Int #TODO

    firstWorkerIdToCompleteSecondInitialPath::Int # Necessary for beautification #TODO
    lastWorkerIdToCompleteSecondInitialPath::Int # Necessary for beautification #TODO

    secondsToSendInitialPathsAndJobsToAllWorkers::Float64  #TODO
    secondsFromStartToHavingReceivedAllInitialPaths::Float64 #TODO

    secondsFromStartToHavingReceivedAllBeautifiedPaths::Float64 #TODO
    secondsForOfflinePreludeBeforeSendingInitialJobs::Float64

    startTime::Float64
    timesAMapSupplementWasRequested::Int
    initialMapDeliverySize::Int

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
            initialMapDeliverySize, # Initial map Delivery Size
        )
    end

end


mutable struct ComparableBenchmarkData
    algorithm::String
    threadCount::Int
    secondsFromStartToCompleted::Float64
    pathCost::Int
end



function GetReportPath_OPT1()
    #TODO
end

function GetComparableDataPath_OPT1()
    #TODO
end

function GetComparableDataPath_SingleThreaded()
    #TODO
end

function GetReportPath_SingleThreaded()
    #TODO
end

function SaveComparable()
end

function SaveReport(report::String, path::String)
    # TODO
end


function OPT1_AverageBenchmarkData(datas::Vector{BenchmarkData_MasterCore})
    if length(datas) == 0
        error("Tried to average a benchmark vector of 0 elements")
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

    # TODO: Before moving on, check if this list comprehension thing works or not.
    all_lastWorkerIdToCompleteSecondInitialPath::Vector{Float64} = [Float64(w.lastWorkerIdToCompleteSecondInitialPath) for w in warmupDiscarded]
    averaged.lastWorkerIdToCompleteSecondInitialPath = Int(mean(all_lastWorkerIdToCompleteSecondInitialPath))
    # TODO: The remaining values 


end



# the \ skips cancels a newline in the string
function OPT1_GenerateWorkerReport(workerData::BenchmarkData_WorkerCore)::String
    report::String = "
        +++WORKER REPORT FOR WORKER $(workerData.workerId)+++

        ---END OF REPORT FOR WORKER $(workerData.workerId)---
    "

    return report
end


function OPT1_GenerateBenchmarkReport(masterData::BenchmarkData_MasterCore, workerData::Vector{MpiCompatible_BenchmarkData_WorkerCore})::String
    m::BenchmarkData_MasterCore = masterData
    equivalentWidthHeight::Int = Int(sqrt(m.totalMapSize))
    report::String = "
        +++MASTER REPORT FOR [$(masterData.mapName)] WITH $(masterData.workerCount) WORKERS+++

        | Map Info
        Total Map Size: $(m.totalMapSize) (Equivalent to a $(equivalentWidthHeight)x$(equivalentWidthHeight) map)

        | Path Cost
        Initial Path Cost: $(m.initialPathCost)
        Beautified Path Cost: $(m.beautifiedPathCost)

        | Load Balance
        First worker to complete the second initial path: $(m.firstWorkerIdToCompleteSecondInitialPath)
        Last worker to complete the second initial path: $(m.lastWorkerIdToCompleteSecondInitialPath)

        | Hyperparameter Configuration
        Initial map delivery size: $(m.initialMapDeliverySize)
        Number of times a map supplement was requested: $(m.timesAMapSupplementWasRequested)


        | Master Overhead
        Seconds for offline prelude before sending initial jobs: $(m.secondsForOfflinePreludeBeforeSendingInitialJobs)
        Seconds to send initial paths and jobs to all workers: $(m.secondsToSendInitialPathsAndJobsToAllWorkers)

        | Path generation time
        Seconds from start to having received all Initial Paths: $(m.secondsFromStartToHavingReceivedAllInitialPaths)
        Seconds from start to having received all Beautified Paths: $(m.secondsFromStartToHavingReceivedAllBeautifiedPaths)
        Seconds between having received all Initial Paths and all Beautified Paths: $(m.secondsFromStartToHavingReceivedAllBeautifiedPaths - m.secondsFromStartToHavingReceivedAllInitialPaths)
    "
    return report
end

function GenerateBenchmarkReport_SingleThreaded

end

