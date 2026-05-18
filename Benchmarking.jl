function HelloWorldFromBenchmarking()
    println("Hello world from Benchmarking!")
end


mutable struct BenchmarkData_WorkerCore
    workerId::Int # WorkerId is workerRank - 1
    numberOfTimesMapDataWasNotAvailableAndWeHadToWait::Int #TODO

    totalMapTilesCollected::Int #TODO
    tilesExplored::Int #TODO

    secondsSpentWaitingForMapDataToComeIn::Float64 #TODO
    secondsFromReceivingJobToHavingSentBeautifiedPaths::Float64 #TODO

    secondsWaitingForInitialJobAndMapDataToComeIn::Float64 #TODO
    numberOfTimesNewMapDataWasRequested::Int #TODO


    function BenchmarkData_WorkerCore(workerRank::Int)::BenchmarkData_WorkerCore
        new(
            workerRank - 1, # Worker id
            0, # Number of Time map data was not available and we had to wait
            0, # Total Map Tiles Collected 
            0, # Tiles Explored 
            0, # Seconds spent idle waiting for map data to come in 
            0, # Seconds between receiving job and having sent beautified paths in return
            0, # Seconds spent waiting for the initial job and map data to come in
            0, # Number of times new map data was requested (should be minimized)
        )
    end
end

mutable struct BenchmarkData_MasterCore
    workerCount::Int
    totalMapSize::Int #TODO

    initialPathCost::Int #TODO
    beautifiedPathCost::Int #TODO

    firstWorkerIdToCompleteSecondInitialPath::Int # Necessary for beautification #TODO
    lastWorkerIdToCompleteSecondInitialPath::Int # Necessary for beautification #TODO

    secondsToSentInitialPathsAndJobsToAllWorkers::Float64  #TODO
    secondsFromStartToHavingReceivedAllInitialPaths::Float64 #TODO
    secondsFromStartToHavingReceivedAllBeautifiedPaths::Float64 #TODO

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




# the \ skips cancels a newline in the string
function GenerateWorkerReport_OPT1(workerData::BenchmarkData_WorkerCore)::String
    report::String = "
        +++WORKER REPORT FOR WORKER $(workerData.workerId)+++

        ---END OF REPORT FOR WORKER $(workerData.workerId)---
    "

    return report
end


function GenerateBenchmarkReport_OPT1(masterData::BenchmarkData_MasterCore, workerData::Vector{BenchmarkData_WorkerCore})::String
    #TODO
    return "Unimplemented GenerateBnechmarkReport"
end

function GenerateBenchmarkReport_SingleThreaded

end

