using DataStructures
using Random
using Base.Threads

function SleepRandomForThreadTesting()
    min = 0.000005
    max = 0.00005
    sleepTime = rand() * (max - min) + min
    sleep(sleepTime)
    # println("Done sleeping")
end

pathfindingA_Count = 0
pathfindingB_Count = 0
pathfindingA_Necessary = rand(10:1000_000)
pathfindingB_Necessary = rand(100:1000_000)
function pseudo_Pathfinding_PathA()
    global pathfindingA_Necessary
    global pathfindingA_Count
    pathfindingA_Count += 1
    return pathfindingA_Count >= pathfindingA_Necessary
end

function pseudo_Pathfinding_PathB()
    global pathfindingB_Count
    global pathfindingB_Necessary
    pathfindingB_Count += 1
    return pathfindingB_Count >= pathfindingB_Necessary
end



function PseudoWorkerCore()
    println("Hello world: PseudoWorkerCore")
    lock_makeSupplementRequest = Threads.ReentrantLock()
    cond_makeSupplementRequest = Threads.Condition(lock_makeSupplementRequest)
    p = Pseudo_WorkerCore(
        Threads.Atomic{Bool}(false),
        #
        Threads.Atomic{Bool}(false),
        Threads.Atomic{Bool}(false),
        #
        Threads.Atomic{Bool}(false),
        Threads.Atomic{Bool}(false),
        #
        Int[],
        Int[],
        #
        Threads.ReentrantLock(),
        #
        lock_makeSupplementRequest,
        cond_makeSupplementRequest, Threads.Atomic{Bool}(false)
    )

    # Initially, the map tiles for A and B are ready, as the master sent those with the jobs
    p.pathATilesReady[] = true
    p.pathBTilesReady[] = true


    println("Going to spawn the MPI thread")
    @spawn pseudo_WorkerMPI(p)
    println("Going to start working")
    while p.readyToStart[] == false
    end
    pseudo_WorkerWorker(p)
end

mutable struct Pseudo_WorkerCore
    isDone::Threads.Atomic{Bool}

    pathATilesNecessary::Threads.Atomic{Bool}
    pathATilesReady::Threads.Atomic{Bool}

    pathBTilesNecessary::Threads.Atomic{Bool}
    pathBTilesReady::Threads.Atomic{Bool}

    productionTiles::Vector{Int}
    workingTiles::Vector{Int}

    lock_ProductionTiles::ReentrantLock

    lock_MakeSupplementRequest::Threads.ReentrantLock
    cond_MakeSupplementRequest::Threads.Condition

    readyToStart::Threads.Atomic{Bool}
end




function pseudo_AddProductionTilesToWorkingTiles()
    SleepRandomForThreadTesting()
end

function pseudo_WorkerWorker(p::Pseudo_WorkerCore)
    global pathfindingA_Count
    global pathfindingB_Count
    pathADone = false
    pathBDone = false

    while true
        if pathADone == false
            while p.pathATilesReady[] == false
                # Busy waiting for the tiles to be ready. 
                yield()
            end

            if p.pathATilesNecessary[]
                # println("Worker: PathA Tiles were necessary, so we're gonna lock production tiles and read them ")
                lock(p.lock_ProductionTiles)
                pseudo_AddProductionTilesToWorkingTiles()
                # println("Worker: PathA tiles were processed. Unlocking production tiles lock now")
                unlock(p.lock_ProductionTiles)
            end
            pathADone = pseudo_Pathfinding_PathA()
        end
        if pathADone == false
            println("PathA wasnt done yet. Progress: $pathfindingA_Count")
            lock(p.lock_MakeSupplementRequest)
            p.pathATilesReady[] = false
            p.pathATilesNecessary[] = true
            notify(p.cond_MakeSupplementRequest)
            unlock(p.lock_MakeSupplementRequest)
        end

        if pathBDone == false
            while p.pathBTilesReady[] == false
                # Busy waiting for the tiles to be ready
                yield()
            end

            if p.pathBTilesNecessary[]
                lock(p.lock_ProductionTiles)
                pseudo_AddProductionTilesToWorkingTiles()
                unlock(p.lock_ProductionTiles)
            end
            pathBDone = pseudo_Pathfinding_PathB()
        end
        if pathBDone == false
            println("PathB wasnt done yet. Progress: $pathfindingB_Count")
            lock(p.lock_MakeSupplementRequest)
            p.pathBTilesReady[] = false
            p.pathBTilesNecessary[] = true
            notify(p.cond_MakeSupplementRequest)
            unlock(p.lock_MakeSupplementRequest)
        end

        bothDone = pathADone && pathBDone
        p.isDone[] = bothDone
        if (bothDone)
            lock(p.lock_MakeSupplementRequest)
            notify(p.cond_MakeSupplementRequest)
            unlock(p.lock_MakeSupplementRequest)
            println("Worker is done! Both are done!")
            break
        end
    end
end

function pseudo_SendSupplementRequest()
    SleepRandomForThreadTesting()
end

function pseudo_WaitAndProcessMapSupplement()
    SleepRandomForThreadTesting()
    return [1]
end

function pseudo_WorkerMPI(p::Pseudo_WorkerCore)

    waitingForSupplement_A = false
    waitingForSupplement_B = false
    lock(p.lock_MakeSupplementRequest)
    p.readyToStart[] = true
    # println("Producer: successfully acquired the initial lock on MakeSupplementRequest")
    while true
        # println("Producer: LOOOOP : Before the isDoneCheck")
        if p.isDone[]
            break
        end

        if waitingForSupplement_A
            lock(p.lock_ProductionTiles)
            p.productionTiles = pseudo_WaitAndProcessMapSupplement()
            p.pathATilesReady[] = true
            unlock(p.lock_ProductionTiles)
            waitingForSupplement_A = false
        end
        if waitingForSupplement_B
            lock(p.lock_ProductionTiles)
            p.productionTiles = pseudo_WaitAndProcessMapSupplement()
            p.pathBTilesReady[] = true
            unlock(p.lock_ProductionTiles)
            waitingForSupplement_B = false
        end

        # We're either woken up by worker wanting us to make a map request, or because worker is done.
        wait(p.cond_MakeSupplementRequest)

        if p.pathATilesNecessary[] == false && p.pathBTilesNecessary[] == false
            println("Neither A or B were necessary, we are done")
            break
        end

        if p.pathATilesNecessary[]
            waitingForSupplement_A = true
            p.pathATilesNecessary[] = false
            pseudo_SendSupplementRequest()
        end

        if p.pathBTilesNecessary[]
            waitingForSupplement_B = true
            p.pathBTilesNecessary[] = false
            pseudo_SendSupplementRequest()

        end
    end

    println("Producer: We're done!")
    unlock(p.lock_MakeSupplementRequest)
end
