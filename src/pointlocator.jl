function query(node::TrapezoidalSearchNode, edge::E)
    node.condition[1] == 0 && return node.data
    p = edge.p
    if node.condition[1] == 1
        if p.x < node.condition[2].p.x
            # println("Point left: ", node.condition[2].p)
            return query(node.left, edge)
        else
            # println("Point right: ", node.condition[2].p)
            return query(node.right, edge)
        end
    else
        side = sideof(node.condition[2], p)
        if side == 1
            # println("Edge left: ", node.condition[2])
            return query(node.left, edge)
        elseif side == -1
            # println("Edge right: ", node.condition[2])
            return query(node.right, edge)
        else
            side = sideof(node.condition[2], edge.q)
            if side == 1
                # println("Edge left (2): ", node.condition[2])
                return query(node.left, edge)
            elseif side == -1
                # println("Edge right (2): ", node.condition[2])
                return query(node.right, edge)
            else
                # TODO: propagate error from here
                # println("You've got to be kidding...")
                return node.data
            end
        end
    end
end

function query(node::TrapezoidalSearchNode, p::V)
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
        side = sideof(node.condition[2], p)
        if side == 1
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
        return sideof(s, t.rb.top.q) == 1 ? t.rb : t.rt
    end

    # General position
    return sideof(s, t.rightp) == 1 ? t.rb : t.rt
end

function initialsplit!(t, s)
    p = lp(s)
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
    rightp = t.rightp.x < rp(s).x ? t.rightp : rp(s)

    if topt.top == t.top
        topt.rightp = rightp
    else
        topt2 = buildnode(t.leftp, rightp, t.top, edge(s), lhs(s))
        topt.rb = topt2
        topt2.lb = topt
        topt = topt2

        topt.lt = t.lt
        if topt.lt !== nothing
            topt.lt.rt = topt
        end
    end

    topt.rt = t.rt
    if topt.rt !== nothing
        topt.rt.lt = topt
    end

    return topt
end

function bottomsplit!(t, s, bott)
    rightp = t.rightp.x < rp(s).x ? t.rightp : rp(s)

    if bott.bottom == t.bottom
        bott.rightp = rightp
    else
        bott2 = buildnode(t.leftp, rightp, edge(s), t.bottom, rhs(s))
        bott.rt = bott2
        bott2.lt = bott
        bott = bott2

        bott.lb = t.lb
        if bott.lb != nothing
            bott.lb.rb = bott
        end
    end

    bott.rb = t.rb
    if bott.rb !== nothing
        bott.rb.lb = bott
    end


    return bott
end

function finalsplit!(t, s)
    q = rp(s)
    node = t.node
    node.data = nothing
    t.node = nothing

    if t.rightp.x <= q.x
        return true, findadjacent(s, t)
    end

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

    return false, t
end

function update!(tree::TrapezoidalSearchNode, s)
    t = query(tree, edge(s))

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

function buildsearch(s)
    bb = buildnode(boundingbox(s))
    root = bb.node
    for item in s
        update!(root, item)
    end

    return root
end

