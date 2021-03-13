# Based on https://math.stackexchange.com/questions/3176543/intersection-point-of-2-lines-defined-by-2-points-each/3176590
function intersection(e1::E, e2::E, tol = 1e-15)
    nx = e1.q.x - e1.p.x
    ny = e1.q.y - e1.p.y
    mx = e2.p.x - e2.q.x
    my = e2.p.y - e2.q.y
    px = e2.p.x - e1.p.x
    py = e2.p.y - e1.p.y

    D = nx*my - ny*mx
    Qx = my*px - mx*py
    Qy = nx*py - ny*px

    (((D > 0) & (Qx < 0)) | ((D > 0) & (Qy < 0)) | ((D < 0) & (Qx > 0)) | ((D < 0) & (Qy > 0))) && return false, e1.p
    ((abs(D) < abs(Qx)) | (abs(D) < abs(Qy))) && return false, e1.p
    abs(D) < tol  && return false, e1.p
    t = Qx/D
    vx = e1.p.x + t*nx
    vy = e1.p.y + t*ny

    return true, V(vx, vy)
end


function islesswithp(s1::E, s2::E, p::V, tol = 1e-15)
    side = sideof(s1, p, tol)
    if side == 1
        return true
    elseif side == -1
        return false
    end
    side = sideof(s1, s2.q, tol)

    # Warning! If two segments coincide, then this function return false!
    if side == 1
        return true
    else
        return false
    end
end

"""
    insert_node!(tree::RBTree, node::RBTreeNode, p::V, tol = 1e-15)

Inserts `node` at proper location by traversing through the `tree` in a binary-search-tree fashion.
"""
function insert_node!(tree::RBTree, node::RBTreeNode, p::V, tol = 1e-15)
    node_y = nothing
    node_x = tree.root

    while node_x !== tree.nil
        node_y = node_x
        if islesswithp(node_x.data, node.data, p, tol)
        # if node.data < node_x.data
            node_x = node_x.rightChild
        else
            node_x = node_x.leftChild
        end
    end

    node.parent = node_y
    if node_y == nothing
        tree.root = node
    elseif islesswithp(node_y.data, node.data, p, tol)
    # elseif node.data < node_y.data
        node_y.rightChild = node
    else
        node_y.leftChild = node
    end
end

"""
    insert!(tree, key, p, tol = 1e-15)

Inserts `key` in the `tree` if it is not present.
"""
function Base.insert!(tree::RBTree{K}, d::K, p::V, tol = 1e-15) where K
    # if the key exists in the tree, no need to insert
    # haskey(tree, d) && return tree

    # insert, if not present in the tree
    node = RBTreeNode{K}(d)
    node.leftChild = node.rightChild = tree.nil

    insert_node!(tree, node, p, tol)

    if node.parent == nothing
        node.color = false
    elseif node.parent.parent == nothing
        ;
    else
        fix_insert!(tree, node)
    end
    tree.count += 1
    return tree
end

"""
    delete!(tree::RBTree, key, p, tol)

Deletes `key` from `tree`, if present, else returns the unmodified tree.
"""
function Base.delete!(tree::RBTree{K}, d::K, p, tol = 1e-15) where K
    z = tree.nil
    node = tree.root

    while node !== tree.nil
        if node.data == d
            z = node
        end

        if islesswithp(d, node.data, p, tol)
        # if d < node.data
            node = node.leftChild
        else
            node = node.rightChild
        end
    end

    (z === tree.nil) && return tree

    y = z
    y_original_color = y.color
    x = RBTreeNode{K}()
    if z.leftChild === tree.nil
        x = z.rightChild
        rb_transplant(tree, z, z.rightChild)
    elseif z.rightChild === tree.nil
        x = z.leftChild
        rb_transplant(tree, z, z.leftChild)
    else
        y = minimum_node(tree, z.rightChild)
        y_original_color = y.color
        x = y.rightChild

        if y.parent == z
            x.parent = y
        else
            rb_transplant(tree, y, y.rightChild)
            y.rightChild = z.rightChild
            y.rightChild.parent = y
        end

        rb_transplant(tree, z, y)
        y.leftChild = z.leftChild
        y.leftChild.parent = y
        y.color = z.color
    end

    !y_original_color && delete_fix(tree, x)
    tree.count -= 1
    return tree
end

function Base.pop!(tree::RBTree{K}, p::V, tol = 1e-15) where K
    z = search_edge(tree, p, tol)

    (z === tree.nil) && return z

    y = z
    y_original_color = y.color
    x = RBTreeNode{K}()
    if z.leftChild === tree.nil
        x = z.rightChild
        rb_transplant(tree, z, z.rightChild)
    elseif z.rightChild === tree.nil
        x = z.leftChild
        rb_transplant(tree, z, z.leftChild)
    else
        y = minimum_node(tree, z.rightChild)
        y_original_color = y.color
        x = y.rightChild

        if y.parent == z
            x.parent = y
        else
            rb_transplant(tree, y, y.rightChild)
            y.rightChild = z.rightChild
            y.rightChild.parent = y
        end

        rb_transplant(tree, z, y)
        y.leftChild = z.leftChild
        y.leftChild.parent = y
        y.color = z.color
    end

    !y_original_color && delete_fix(tree, x)
    tree.count -= 1
    return z
end

function search_edge(tree::RBTree{K}, p::V, tol = 1e-15) where K
    node = tree.root
    while node !== tree.nil
        side = sideof(node.data, p, tol)
        side == 0 && return node
        if side == -1
            node = node.leftChild
        else
            node = node.rightChild
        end
    end
    return node
end

########################################
# AbstractTrees beautifiers
# WARNING!!! TYPE PIRACY!!! DO SOMETHING!!!
########################################

children(tree::RBTree) = children(tree.root)
function children(node::RBTreeNode)
    if node.leftChild === nothing
        if node.rightChild === nothing
            return ()
        else
            return (node.rightChild, )
        end
    else
        if node.rightChild === nothing
            return (node.leftChild, )
        else
            return (node.leftChild, node.rightChild)
        end
    end
end

## Things that make printing prettier
printnode(io::IO, tree::RBTree) = printnode(io, tree.root)
printnode(io::IO, node::RBTreeNode) = print(io, node.data)

function leftmost(tree)
    node = tree.root
    while node.leftChild !== tree.nil
        node = node.leftChild
    end
    return node
end
