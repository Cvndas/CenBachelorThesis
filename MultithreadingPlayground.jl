using DataStructures
using Random
using Base.Threads

function SleepRandomForThreadTesting()
    min = 0.000005
    max = 0.05
    sleepTime = rand() * (max - min) + min
    sleep(sleepTime)
    # println("Done sleeping")
end

pathfindingA_Count = 0
pathfindingB_Count = 0
pathfindingA_Necessary = rand(10:100)
pathfindingB_Necessary = rand(30:130)
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
        yield()
    end
    pseudo_WorkerPathfinder(p)
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


# Utilizing the fact that Atomic{} is a reference type, to refer to specific variables from the other struct
mutable struct Pseudo_WorkerWorkerState
    isPathA::Bool
    pathDone::Bool
    pathTilesNecessary::Threads.Atomic{Bool}
    pathTilesReady::Threads.Atomic{Bool}
end


function pseudo_AddProductionTilesToWorkingTiles()
    SleepRandomForThreadTesting()
end
function pseudo_PrintPathProgress(w::Pseudo_WorkerWorkerState)
    # These two are just for this pseudo implementation. Won't be part of the true implementation
    global pathfindingA_Count
    global pathfindingB_Count
    if w.isPathA
        println("Path A wasnt done yet. Progress: $pathfindingA_Count")
    else
        println("Path B wasnt done yet. Progress: $pathfindingB_Count")
    end
end

function pseudo_Pathfind(w::Pseudo_WorkerWorkerState)
    if w.isPathA
        return pseudo_Pathfinding_PathA()
    else
        return pseudo_Pathfinding_PathB()
    end
end


function pseudo_WorkerPathfinder(p::Pseudo_WorkerCore)

    a = Pseudo_WorkerWorkerState(true, false, p.pathATilesNecessary, p.pathATilesReady)
    b = Pseudo_WorkerWorkerState(false, false, p.pathBTilesNecessary, p.pathBTilesReady)

    while true
        pseudo_WorkerPathfind(p, a)
        pseudo_WorkerPathfind(p, b)
        bothDone = a.pathDone && b.pathDone
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

function pseudo_WorkerPathfind(p::Pseudo_WorkerCore, w::Pseudo_WorkerWorkerState)
    if w.pathDone == false
        while w.pathTilesReady[] == false
            yield()
        end

        if w.pathTilesNecessary[]
            lock(p.lock_ProductionTiles)
            pseudo_AddProductionTilesToWorkingTiles()
            unlock(p.lock_ProductionTiles)
        end
        w.pathDone = pseudo_Pathfind(w)
    end
    if w.pathDone == false
        pseudo_PrintPathProgress(w)
        lock(p.lock_MakeSupplementRequest)
        w.pathTilesReady[] = false
        w.pathTilesNecessary[] = true
        notify(p.cond_MakeSupplementRequest)
        unlock(p.lock_MakeSupplementRequest)
    end
end




function pseudo_SendSupplementRequest()
    SleepRandomForThreadTesting()
end

function pseudo_WaitAndProcessMapSupplement()
    SleepRandomForThreadTesting()
    return [1]
end

function pseudo_MapSupplementIsInTheMail()
    return rand(1:10) > 5
end


#=
Reasoning about why we can't interlink reading map supplements from master with reading map supplement REQUESTS from worker: 
Doing the wait() again while we are waiting for a supplement to come in is not just expensive, but
incorrect. Then we're hoping that the worker is gonna wake us up with another "please request another supplement". 
If that doesn't come, of it the supplement is for the same path as the currently pending one, we're overwriting business.
Basically, when any request (or both) is made, we HAVE to serve back a map supplement before accepting more requests.
=#

function pseudo_WorkerMPI(p::Pseudo_WorkerCore)
    # Prelude
    waitingForSupplement_A = false
    waitingForSupplement_B = false
    # The correctness of this algorithn depends on us having this lock at all times, except for when we call wait.
    lock(p.lock_MakeSupplementRequest)
    p.readyToStart[] = true

    while true
        while waitingForSupplement_A || waitingForSupplement_B
            # Busy wait, only because we don't have this hooked up to MPI. Otherwise, we woud IProbe()
            if waitingForSupplement_A && pseudo_MapSupplementIsInTheMail()
                lock(p.lock_ProductionTiles)
                p.productionTiles = pseudo_WaitAndProcessMapSupplement()
                p.pathATilesReady[] = true
                unlock(p.lock_ProductionTiles)
                waitingForSupplement_A = false
            end
            if waitingForSupplement_B && pseudo_MapSupplementIsInTheMail()
                lock(p.lock_ProductionTiles)
                p.productionTiles = pseudo_WaitAndProcessMapSupplement()
                p.pathBTilesReady[] = true
                unlock(p.lock_ProductionTiles)
                waitingForSupplement_B = false
            end
            yield()
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
