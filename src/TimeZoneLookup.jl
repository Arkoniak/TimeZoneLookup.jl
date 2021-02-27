module TimeZoneLookup

using Shapefile
using Setfield
using AbstractTrees
import Base: isless, zero, similar, show

export buildedges, mergeedges, buildedges!, buildmega, boundingbox, TrapezoidalSearchNode, TrapezoidData, query, Trapezoid, E, V
export faceof, EData, lhs, rhs, lp, rp, update!, sideof, buildsearch

include("structs.jl")
include("utils.jl")
include("pointlocator.jl")

end # module
