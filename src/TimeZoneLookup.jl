module TimeZoneLookup

using Shapefile
using Setfield
using AbstractTrees
import AbstractTrees: children, printnode
import Base: isless, zero, similar, show, insert!, delete!, pop!
using DataStructures
import DataStructures: insert_node!, RBTreeNode, fix_insert!, search_node, rb_transplant, minimum_node, delete_fix

export buildedges, mergeedges, buildedges!, buildmega, boundingbox, TrapezoidalSearchNode, TrapezoidData, query, Trapezoid, E, V, HE, Face
export faceof, EData, lhs, rhs, lp, rp, update!, sideof, buildsearch

export HE, Face, DCEL, twin, next, prev, loaddcel

include("structs.jl")
include("utils.jl")
include("pointlocator.jl")
include("dcel.jl")
include("sweep.jl")

end # module
