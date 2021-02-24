module TimeZoneLookup

using Shapefile
using Setfield
import Base: isless, zero, similar

export buildedges, mergeedges, buildedges!, buildmega, boundingbox, TrapezoidalSearchNode, TrapezoidData, query, Trapezoid, E, V
export faceof, EData, lhs, rhs, lp, rp, update!

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

struct E{T}
    p::V{T}
    q::V{T}
end
zero(::Type{E{T}}) where T = E(zero(V{T}), zero(V{T}))

struct EData{T}
    e::E{T}
    l::Int # Left hand face
    r::Int # Right hand face
end

lhs(x::EData) = x.l
rhs(x::EData) = x.r
edge(x::EData) = x.e
lp(x::EData) = edge(x).p
rp(x::EData) = edge(x).q

function faceof(x::EData, r::V)
    e = x.e
    p = e.p
    q = e.q
    d1 = q.x - p.x
    d2 = q.y - p.y
    d3 = p.x*q.y - p.y*q.x
    ld = d1*r.y - d2*r.x
    ld > d3 ? lhs(x) : rhs(x)
end

function sideof(x::E, r::V)
    p = x.p
    q = x.q
    d1 = q.x - p.x
    d2 = q.y - p.y
    d3 = p.x*q.y - p.y*q.x
    ld = d1*r.y - d2*r.x
    return ld > d3
end

isless(e1::E{T}, e2::E{T}) where T = isless((e1.p, e1.q), (e2.p, e2.q))
isless(v1::V{T}, v2::V{T}) where T = isless((v1.x, v1.y), (v2.x, v2.y))

struct Trapezoid{T}
    leftp::V{T}
    rightp::V{T}
    top::E{T}
    bottom::E{T}
    face::Int
end

abstract type AbstractTrapezoidData end
mutable struct TrapezoidalSearchNode{T, T1 <: AbstractTrapezoidData} 
    left::Union{TrapezoidalSearchNode{T, T1}, Nothing}
    right::Union{TrapezoidalSearchNode{T, T1}, Nothing}
    condition::Tuple{Int, E{T}}
    data::Union{T1, Nothing}
end

mutable struct TrapezoidData{T} <: AbstractTrapezoidData
    t::Trapezoid{T}
    rb::Union{TrapezoidData{T}, Nothing} # Right bottom adjacent trapezoid
    rt::Union{TrapezoidData{T}, Nothing} # Right top adjacent trapezoid
    node::Union{TrapezoidalSearchNode{T, TrapezoidData{T}}, Nothing}    # Node where this trapezoid can be found
end

TrapezoidalSearchNode(data::TrapezoidData{T}) where T = TrapezoidalSearchNode{T, TrapezoidData{T}}(nothing, nothing, (0, zero(E{T})), data)
TrapezoidData(t::Trapezoid{T}) where T = TrapezoidData(t, nothing, nothing, nothing)


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
            return query(node.left, p)
        else
            return query(node.right, p)
        end
    else
        if sideof(node.condition[2], p)
            return query(node.left, p)
        else
            return query(node.right, p)
        end
    end
end

function buildnode(t)
    td = TrapezoidData(t)
    tn = TrapezoidalSearchNode(td)
    td.node = tn

    return td, tn
end

similar(node::TrapezoidalSearchNode{T, T1}) where {T, T1} = TrapezoidalSearchNode{T, T1}(nothing, nothing, (0, zero(E{T}), nothing))

function update!(tree::TrapezoidalSearchNode, s)
    td = query(tree, lp(s))
    t = td.t
    p = lp(s)
    q = rp(s)
    e = edge(s)

    node = td.node
    prevnodeexists = false
    tdprev = td

    if p.x > t.leftp.x && p.x < t.rightp.x
        # Transforming node to internal and adding type 1 condition
        node.data.node = nothing
        node.data = nothing
        node.condition = (1, E(p, p))

        # Split initial trapezoid and add results to the left and right nodes
        t1 = Trapezoid(t.leftp, p, t.top, t.bottom, t.face)
        td1, tn1 = buildnode(t1)
        node.left = tn1

        t2 = Trapezoid(p, t.rightp, t.top, t.bottom, t.face)
        td2, tn2 = buildnode(t2)
        td2.rb = td.rb
        td2.rt = td.rt
        node.right = tn2

        # Fake left trapezoid, just to simplify things
        prevnodeexists = true
        node = tn2
        td = td2
        t = t2
    elseif p.x == t.rightp.x
        # Searching right adjacent node
        if sideof(s, t.rightp)
            td = td.rt
        else
            td = td.rb
        end

        # It shouldn't happen though
        if td === nothing
            return nothing
        end
        prevnodeexists = true
        node = td.node
        t = td.t
    end

    splitting = true
    istopactive = false
    isbotactive = false
    while splitting
        # TODO: what if t.rightp.x == q.x?
        if t.rightp.x > q.x
            splitting = false
            # Introduce rightmost node and split trapezoid vertically
            t1 = Trapezoid(q, t.rightp, t.top, t.bottom, t.face)
            td1, tn1 = buildnode(t1)
            td1.rt = td.rt
            td1.rb = td.rb
            node.right = tn1

            t2 = Trapezoid(t.leftp, q, t.top, t.bottom, t.face)
            td2, tn2 = buildnode(t2)
            node.left = tn2

            node.data.node = nothing
            node.data = nothing
            node.condition = (1, E(q, q))

            tdprev = td1
            t = t2
            td = td2
            node = tn2
        end

        # we are building upper and lower division of the current trapezoid
        if !istopactive
            istopactive = true
            ttop = Trapezoid(t.leftp, t.rightp, t.top, e, lhs(s))
            ttopd, ttopn = buildnode(ttop)
            if prevnodeexists
                tdprev.rt = ttopd
            end
        else
            if ttop.top == t.top
                ttop.rightp = t.rightp
            else
                ttop2 = Trapezoid(t.leftp, t.rightp, t.top, e, lhs(s))
                ttopd2, ttopn = buildnode(ttop2)
                ttopd.rb = ttopd2
                ttopd = ttopd2
                ttop2 = ttop
            end
        end

        if !isbotactive
            isbotactive = true
            tbot = Trapezoid(t.leftp, t.rightp, e, t.bottom, rhs(s))
            tbotd, tbotn = buildnode(tbot)
            if prevnodeexists
                tdprev.rb = tbotd
            end
        else
            if tbot.bot == t.bot
                tbot.rightp = t.rightp
            else
                tbot2 = Trapezoid(t.leftp, t.rightp, t.top, e, rhs(s))
                tbotd2, tbotn = buildnode(tbot2)
                tbotd.rt = tbotd2
                tbotd = tbotd2
                tbot2 = tbot
            end
        end

        node.data.node = nothing
        node.data = nothing
        node.condition = (2, e)
        node.left = ttopn
        node.right = tbotn

        if splitting
            if sideof(s, t.rightp)
                td = td.rt
            else
                td = td.rb
            end
            t = td.t
            node = td.node
        else
            ttopd.rt = tdprev
            tbotd.rb = tdprev
        end
    end
end

end # module
