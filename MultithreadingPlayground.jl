using DataStructures
using Base.Threads

mutable struct MultiThreadedCommunication
    dataQueue::Queue{Int}
    dataRequested::Bool

    queueLock::ReentrantLock
    cond::Threads.Condition

    isDone::Bool
    # TODO: Mutexes, conditional variables, etc.
end

function MultiThreadedTestingGround()
    threadCount = Threads.nthreads()
    if threadCount == 1
        error("To run multithreaded testing ground, start julia with more than 1 thread like julia --threads x")
    end


    lock = ReentrantLock()
    cond = Threads.Condition(lock)

    m = MultiThreadedCommunication(
        Queue{Int}(),
        true,
        lock,
        cond,
        false
    )

    m.isDone = false
    @spawn DataProducer(m)
    DataReader(m)
end

function DataReader(m::MultiThreadedCommunication)
    println("Reader: Begin")
    totalSum = 0
    workRequirement = 1_000_000
    while true
        lock(m.queueLock)
        while isempty(m.dataQueue) == false
            totalSum += dequeue!(m.dataQueue)
        end

        println("Just dequeued some data. Total sum: $totalSum")
        enoughWorkDone = totalSum >= workRequirement
        if enoughWorkDone
            m.isDone = true
            notify(m.cond)
            unlock(m.queueLock)
            break
        end
        m.dataRequested = true
        notify(m.cond)
        unlock(m.queueLock)
    end

    println("Reader is done. Total work done: $totalSum")
end

function DataProducer(m::MultiThreadedCommunication)
    println("Producer: Begin")
    #=
    Idea: 
    Produce a little bit of data, sleep.
    Then 
    =#
    lock(m.queueLock)
    while m.isDone == false
        if m.dataRequested
            for i in 1:1000
                enqueue!(m.dataQueue, 1)
            end
        end
        wait(m.cond)
    end
    unlock(m.queueLock)

    println("Producer is done")
end



function MultiThreadedHelloWorld()


    threadId::Int = Threads.threadid()
    println("Hello world from thread $(threadId)")
end
