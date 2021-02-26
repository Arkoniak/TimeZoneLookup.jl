module TimeZoneLookup

using Shapefile
using Setfield
using AbstractTrees
import Base: isless, zero, similar, show

export buildedges, mergeedges, buildedges!, buildmega, boundingbox, TrapezoidalSearchNode, TrapezoidData, query, Trapezoid, E, V
export faceof, EData, lhs, rhs, lp, rp, update!, sideof, buildsearch

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

faceof(x::EData, r::V) = sideof(x, r) ? lhs(x) : rhs(x)

function sideof(x::E, r::V)
    p = x.p
    q = x.q
    d1 = q.x - p.x
    d2 = q.y - p.y
    d3 = p.y * q.x - p.x * q.y
    ld = d1 * r.y - d2 * r.x
    # @info "Sideof" p q d1 d2 d3 ld
    return ld > d3
end

isless(e1::E{T}, e2::E{T}) where T = isless((e1.p, e1.q), (e2.p, e2.q))
isless(v1::V{T}, v2::V{T}) where T = isless((v1.x, v1.y), (v2.x, v2.y))

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

# For better tree printing and navigation
## Things we need to define
function AbstractTrees.children(node::TrapezoidalSearchNode)
    if node.left === nothing
        if node.right === nothing
            return ()
        else
            return (node.right, )
        end
    else
        if node.right === nothing
            return (node.left, )
        else
            return (node.left, node.right)
        end
    end
end

## Things that make printing prettier
AbstractTrees.printnode(io::IO, node::TrapezoidalSearchNode) = print(io, node)

function buildmega(table)
    s = 0
    for x in table.geometry
        s += length(x.points) - length(x.parts)
    end
    res = Vector{Tuple{E{typeof(table.geometry[1].points[1].x)}, Int, Int}}(undef, s)
    offset = 0
    for (i, poly) in pairs(table.geometry)
        buildedges!(res, offset, poly, i)
        offset += length(poly.points) - length(poly.parts)
    end

    return res
end

function buildedges!(edges, offset, poly, id)
    points = poly.points
    parts = poly.parts

    @inbounds for k in eachindex(parts)
        i1 = parts[k] + 2
        i2 = k == length(parts) ? length(points) : parts[k + 1]
        prev = V(points[i1 - 1].x, points[i1 - 1].y)
        for i in i1:i2
            p = points[i]
            cur = V(p.x, p.y)
            if prev < cur
                edges[i - k + offset] = (E(prev, cur), id, -1)
            else
                edges[i - k + offset] = (E(cur, prev), -1, id)
            end
            prev = cur
        end
    end

    return edges
end

function buildedges(poly, id)
    points = poly.points
    parts = poly.parts
    res = Vector{Tuple{E{typeof(points[1].x)}, Int, Int}}(undef, length(points) - length(parts))
    @inbounds for k in eachindex(parts)
        i1 = parts[k] + 2
        i2 = k == length(parts) ? length(points) : parts[k + 1]
        prev = V(points[i1 - 1].x, points[i1 - 1].y)
        for i in i1:i2
            p = points[i]
            cur = V(p.x, p.y)
            if prev < cur
                res[i - k] = (E(prev, cur), id, -1)
            else
                res[i - k] = (E(cur, prev), -1, id)
            end
            prev = cur
        end
    end

    return res
end

function names2indices(baddies, table)
    m = Dict(map(x -> x[2] => x[1], enumerate(table.tzid)))
    res = Tuple{Int, Int}[]
    for x in baddies
        push!(res, (m[x[1]], m[x[2]]))
    end
    return res
end

function mergeedges(edges, table; precedence = PRECEDENCE)
    precedence = names2indices(precedence, table)
    baddies = Set{Tuple{Int, Int}}()
    edges = sort(edges, by = x -> x[1])
    res = similar(edges, 0)
    prev = edges[1]
    for i in 2:length(edges)
        cur = edges[i]
        if cur[1] != prev[1]
            push!(res, prev)
            prev = cur
        else
            if cur[2] != -1 && prev[2] == -1
                @set! prev[2] = cur[2]
            elseif cur[3] != -1 && prev[3] == -1
                @set! prev[3] = cur[3]
            else
                caught = false
                for prec in precedence
                    if (cur[2] == prec[1] && prev[2] == prec[2]) || (cur[2] == prec[2] && prev[2] == prec[1])
                        @set! prev[2] = prec[1]
                        caught = true
                    elseif (cur[3] == prec[1] && prev[3] == prec[2]) || (cur[3] == prec[2] && prev[3] == prec[1])
                        @set! prev[3] = prec[1]
                        caught = true
                    end
                    caught && break
                end
                if !caught
                    if cur[2] != -1 && prev[2] != -1
                        m1 = min(cur[2], prev[2])
                        m2 = max(cur[2], prev[2])
                        push!(baddies, (m1, m2))
                    elseif cur[3] != -1 && prev[3] != -1
                        m1 = min(cur[3], prev[3])
                        m2 = max(cur[3], prev[3])
                        push!(baddies, (m1, m2))
                    end
                end
            end
        end
    end
    push!(res, prev)

    return res, baddies
end

function boundingbox(poly)
    points = poly.points
    p, rest = Iterators.peel(points)
    p = V(p.x, p.y)
    leftp = p
    rightp = p
    topy = p.y
    bottomy = p.y
    for p in rest
        p = V(p.x, p.y)
        if p < leftp
            leftp = p
        end
        if p > rightp
            rightp = p
        end
        if p.y > topy
            topy = p.y
        end
        if p.y < bottomy
            bottomy = p.y
        end
    end
    top = E(V(leftp.x, topy), V(rightp.x, topy))
    bottom = E(V(leftp.x, bottomy), V(rightp.x, bottomy))

    return Trapezoid(leftp, rightp, top, bottom, -1)
end

function query(node::TrapezoidalSearchNode, p)
    node.condition[1] == 0 && return node.data
    if node.condition[1] == 1
        if p.x < node.condition[2].p.x
            # println("Point left: ", node.condition[2].p)
            return query(node.left, p)
        else
            # println("Point right: ", node.condition[2].p)
            return query(node.right, p)
        end
    else
        if sideof(node.condition[2], p)
            # println("Edge left: ", node.condition[2])
            return query(node.left, p)
        else
            # println("Edge right: ", node.condition[2])
            return query(node.right, p)
        end
    end
end

function buildnode(leftp, rightp, top, bottom, face)
    t = Trapezoid(leftp, rightp, top, bottom, face)
    node = TrapezoidalSearchNode(t)
    t.node = node

    return t
end

function buildnode(t)
    node = TrapezoidalSearchNode(t)
    t.node = node

    return t
end

similar(node::TrapezoidalSearchNode{T, T1}) where {T, T1} = TrapezoidalSearchNode{T, T1}(nothing, nothing, (0, zero(E{T}), nothing))

function findadjacent(s, t)
    # If we have only one adjacent trapezoid, return it
    t.rb === nothing && return t.rt
    t.rt === nothing && return t.rb

    # We have two adjacent trapezoids, must choose one of them
    p = lp(s)
    if t.rightp == p
        return sideof(s, t.rb.top.q) ? t.rb : t.rt
    end

    # General position
    return sideof(s, t.rightp) ? t.rb : t.rt
end

function initialsplit!(t, s)
    p = lp(s)
    if p.x == t.rightp.x
        t = findadjacent(s, t)
    end
    node = t.node

    if p.x > t.leftp.x && p.x < t.rightp.x
        # Transforming node to internal and adding type 1 condition
        t.node = nothing
        node.data = nothing
        node.condition = (1, E(p, p))

        # Split initial trapezoid and add results to the left and right nodes
        # Fake right trapezoid, just to simplify things
        t2 = buildnode(p, t.rightp, t.top, t.bottom, t.face)
        t2.rb = t.rb
        t2.rt = t.rt
        node.right = t2.node

        t.rightp = p
        t = buildnode(t)
        node.left = t.node

        t2.lt = t
        t2.lb = t
        t = t2
    end

    topt = buildnode(p, p, t.top, edge(s), lhs(s))
    bott = buildnode(p, p, edge(s), t.bottom, rhs(s))
    if t.lt !== nothing
        t.lt.rt = topt
        topt.lt = t.lt
    end
    if t.lb !== nothing
        t.lb.rb = bott
        bott.lb = t.lb
    end

    return t, topt, bott
end

# TODO: next couple of functions is redundant
function topsplit!(t, s, topt)
    rightp = min(t.rightp, rp(s))

    if topt.top == t.top
        topt.rightp = rightp
        topt.rt = t.rt
        if t.rt !== nothing
            topt.rt.lt = topt
        end
    else
        topt2 = buildnode(t.leftp, rightp, t.top, edge(s), lhs(s))
        topt.rb = topt2
        topt2.lb = topt
        topt = topt2
    end

    return topt
end

function bottomsplit!(t, s, bott)
    rightp = min(t.rightp, rp(s))

    if bott.bottom == t.bottom
        bott.rightp = rightp
        bott.rb = t.rb
        if t.rb !== nothing
            bott.rb.lb = bott
        end
    else
        bott2 = buildnode(t.leftp, rightp, edge(s), t.bottom, rhs(s))
        bott.rt = bott2
        bott2.lt = bott
        bott = bott2
    end

    return bott
end

function finalsplit!(t, s)
    q = rp(s)
    node = t.node
    node.data = nothing
    t.node = nothing

    if t.rightp.x < q.x
        return true, findadjacent(s, t)
    end

    if t.rightp.x > q.x
        if t.rt !== nothing
            t.rt.lt = t
        end
        if t.rb !== nothing
            t.rb.lb = t
        end
        # Introduce rightmost node and split trapezoid vertically
        t.leftp = q
        t = buildnode(t)
        node.left.data.rt = t
        t.lt = node.left.data

        node.right.data.rb = t
        t.lb = node.right.data

        t2 = buildnode(node.left.data)
        node.left.left = t2.node
        node.left.right = node.right
        node.left.condition = node.condition
        node.left.data = nothing

        node.right = t.node
        node.condition = (1, E(q, q))
    end

    if t.rightp.x == q.x
        if t.rt !== nothing
            node.left.data.rt = t.rt
            t.rt.lt = node.left.data
        end

        if t.rb !== nothing
            node.right.data.rb = t.rb
            t.rb.lb = node.right.data
        end
    end

    return false, t
end

function update!(tree::TrapezoidalSearchNode, s)
    p = lp(s)
    t = query(tree, p)

    # Fix edge case
    if (t.leftp == p) & (t.top.p == p)
        if !sideof(s, t.top.q)
            t = t.lb.rt
        end
    end

    t, topt, bott = initialsplit!(t, s)

    splitting = true
    while splitting
        # we are building upper and lower division of the current trapezoid
        topt = topsplit!(t, s, topt)
        bott = bottomsplit!(t, s, bott)
        
        t.node.left = topt.node
        t.node.right = bott.node
        t.node.condition = (2, edge(s))
        
        splitting, t = finalsplit!(t, s)
    end
end

function buildsearch(s, lb, rt)
    bb = buildnode(lb, rt, E(V(lb.x, rt.y), rt), E(lb, V(rt.x, lb.y)), -1)
    root = bb.node
    for item in s
        update!(root, item)
    end

    return root
end

end # module
