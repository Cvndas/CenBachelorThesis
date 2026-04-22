
# mutable struct MPI_Opt1_WorkerEntry
#     workerRank::Int
#     workerLevel_A::Int
#     workerLevel_B::Int
#     pathAReceived::Bool
#     pathBReceived::Bool
#     function MPI_Opt1_WorkerEntry(workerRank::Int)
#         new(workerRank, 1, 1, false, false)
#     end
# end