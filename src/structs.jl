const PRECEDENCE = [
 ("Asia/Hebron", "Asia/Jerusalem"),
 ("Asia/Urumqi", "Asia/Shanghai"),
 ("Asia/Thimphu", "Asia/Shanghai"),
 ("Asia/Tbilisi", "Europe/Moscow"),
 ("Europe/Belgrade", "Europe/Zagreb"),
 ("Europe/Berlin", "Europe/Luxembourg"),
 ("America/Moncton", "America/New_York"),
 ("Africa/Khartoum", "Africa/Juba"),
 ("America/Juneau", "Etc/GMT+9"),
]

########################################
# map structures
########################################
struct V{T}
    x::T
    y::T
end
zero(::Type{V{T}}) where T = V(zero(T), zero(T))
V(p::Shapefile.Point) = V(p.x, p.y)

function show(io::IO, v::V)
    print(io, "{", v.x, ", ", v.y, "}")
end

struct E{T}
    p::V{T}
    q::V{T}
end
zero(::Type{E{T}}) where T = E(zero(V{T}), zero(V{T}))
function show(io::IO, e::E)
    print(io, e.p, "→", e.q)
end

struct EData{T}
    e::E{T}
    l::Int # Left hand face
    r::Int # Right hand face
end
function show(io::IO, ed::EData)
    print(io, "Edge: ", ed.e, ", ", ed.l, ", ", ed.r)
end

lhs(x::EData) = x.l
rhs(x::EData) = x.r
edge(x::EData) = x.e
lp(x::EData) = edge(x).p
rp(x::EData) = edge(x).q
sideof(x::EData, r::V) = sideof(edge(x), r)

faceof(x::EData, r::V) = sideof(x, r) == 1 ? lhs(x) : rhs(x)

function sideof(x::E, r::V, tol = 0)
    p = x.p
    q = x.q
    d1 = q.x - p.x
    d2 = q.y - p.y
    d3 = p.y * q.x - p.x * q.y
    ld = d1 * r.y - d2 * r.x
    # @info "Sideof" p q d1 d2 d3 ld
    return ld - d3 > tol ? 1 : d3 - ld > tol ? -1 : 0
end

# isless(e1::E{T}, e2::E{T}) where T = isless((e1.p, e1.q), (e2.p, e2.q))
# isless(v1::V{T}, v2::V{T}) where T = isless((v1.x, v1.y), (v2.x, v2.y))
isless(v1::V, v2::V) = (v1.y > v2.y) | ((v1.y == v2.y) & (v1.x < v2.x))

abstract type AbstractTrapezoid end
mutable struct TrapezoidalSearchNode{T, T1 <: AbstractTrapezoid} 
    left::Union{TrapezoidalSearchNode{T, T1}, Nothing}
    right::Union{TrapezoidalSearchNode{T, T1}, Nothing}
    condition::Tuple{Int, E{T}}
    data::Union{T1, Nothing}
end
function show(io::IO, node::TrapezoidalSearchNode)
    print(io, node.data, "; ")
    if node.condition[1] == 0
        print(io, "Leaf")
    elseif node.condition[1] == 1
        print(io, "Point: ", node.condition[2].p)
    else
        print(io, "Edge:  ", node.condition[2])
    end
end

mutable struct Trapezoid{T} <: AbstractTrapezoid
    leftp::V{T}
    rightp::V{T}
    top::E{T}
    bottom::E{T}
    face::Int
    lb::Union{Trapezoid{T}, Nothing} # Left bottom adjacent trapezoid
    lt::Union{Trapezoid{T}, Nothing} # Left top adjacent trapezoid
    rb::Union{Trapezoid{T}, Nothing} # Right bottom adjacent trapezoid
    rt::Union{Trapezoid{T}, Nothing} # Right top adjacent trapezoid
    node::Union{TrapezoidalSearchNode{T, Trapezoid{T}}, Nothing}    # Node where this trapezoid can be found
end
Trapezoid(leftp::V{T}, rightp::V{T}, top::E{T}, bottom::E{T}, face) where T = Trapezoid(leftp, rightp, top, bottom, face, nothing, nothing, nothing, nothing, nothing)

TrapezoidalSearchNode(data::Trapezoid{T}) where T = TrapezoidalSearchNode{T, Trapezoid{T}}(nothing, nothing, (0, zero(E{T})), data)

function show(io::IO, t::Trapezoid)
    print(io, "Trapezoid: ", t.leftp, ", ", t.rightp, ", ", t.top, ", ", t.bottom, ", ", t.face)
end

