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
    res = Vector{EData{typeof(table.geometry[1].points[1].x)}}(undef, s)
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
                edges[i - k + offset] = EData(E(prev, cur), -1, id)
            else
                edges[i - k + offset] = EData(E(cur, prev), id, -1)
            end
            prev = cur
        end
    end

    return edges
end

function buildedges(poly, id)
    points = poly.points
    parts = poly.parts
    res = Vector{EData{typeof(points[1].x)}}(undef, length(points) - length(parts))
    @inbounds for k in eachindex(parts)
        i1 = parts[k] + 2
        i2 = k == length(parts) ? length(points) : parts[k + 1]
        prev = V(points[i1 - 1].x, points[i1 - 1].y)
        for i in i1:i2
            p = points[i]
            cur = V(p.x, p.y)
            if prev < cur
                res[i - k] = EData(E(prev, cur), -1, id)
            else
                res[i - k] = EData(E(cur, prev), id, -1)
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
    edges = sort(edges, by = x -> edge(x))
    res = similar(edges, 0)
    prev = edges[1]
    for i in 2:length(edges)
        cur = edges[i]
        if edge(cur) != edge(prev)
            push!(res, prev)
            prev = cur
        else
            if lhs(cur) != -1 && lhs(prev) == -1
                @set! prev.l = cur.l
            elseif cur.r != -1 && prev.r == -1
                @set! prev.r = cur.r
            else
                caught = false
                for prec in precedence
                    if (cur.l == prec[1] && prev.l == prec[2]) || (cur.l == prec[2] && prev.l == prec[1])
                        @set! prev.l = prec[1]
                        caught = true
                    elseif (cur.r == prec[1] && prev.r == prec[2]) || (cur.r == prec[2] && prev.r == prec[1])
                        @set! prev.r = prec[1]
                        caught = true
                    end
                    caught && break
                end
                if !caught
                    if cur.l != -1 && prev.l != -1
                        m1 = min(cur.l, prev.l)
                        m2 = max(cur.l, prev.l)
                        push!(baddies, (m1, m2))
                    elseif cur.r != -1 && prev.r != -1
                        m1 = min(cur.r, prev.r)
                        m2 = max(cur.r, prev.r)
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

function boundingbox(v::AbstractVector{T}) where {T <: EData}
    ed, rest = Iterators.peel(v)
    p = edge(ed).p
    leftp = p
    rightp = p
    topy = p.y
    bottomy = p.y
    for ed in rest
        p = edge(ed).p
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

