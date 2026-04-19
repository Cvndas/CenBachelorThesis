
using GLMakie
using Colors
using Makie.Colors
using Random
using Dates









function NotImplemented()
    error("Not Implemented")
end



function InvertedColor(color)
    asRgba = RGBAf(color)
    return RGBAf(1 - asRgba.r, 1 - asRgba.g, 1 - asRgba.b, asRgba.alpha)
end