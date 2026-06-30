(
    seed=5,
    MAZE_SIZE_X=500,
    MAZE_SIZE_Y=500,
    AVERAGING_ITERATIONS=1,
    HEURISTIC_BOOSTER=1,
    PATH_BenchmarkingRun_A=joinpath("Benchmarks", "RunA"),
    PATH_SingleRun=joinpath("Benchmarks", "SingleRun"),
    PATH_DasRun=joinpath("Benchmarks", "DAS5"),
    USE_LEVELING_STRATEGY_V2=true,
    LEVEL_SCALING=3, # Supporting 1 2 3 and 4, with 4 being the weakest, and 1 being the strongest
)
