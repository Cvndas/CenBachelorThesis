
using GLMakie
using Colors
using Makie.Colors
using Random
using Dates





function InitializeSeed()::Int
    config = include("Config.jl")
    seed = config.seed
    # seed = 5
    if seed < 0
        seed = Int(round(time()))
    end
    # println("Initialized with seed $seed")
    Random.seed!(seed)
    return seed
end



function NotImplemented()
    error("Not Implemented")
end



function InvertedColor(color)
    asRgba = RGBAf(color)
    return RGBAf(1 - asRgba.r, 1 - asRgba.g, 1 - asRgba.b, asRgba.alpha)
end