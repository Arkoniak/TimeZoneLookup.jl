mutable struct HE{T}
    e::E{T}
    t::HE{T}
    next::HE{T}
    prev::HE{T}
    fid::Int
    function HE(e::E{T}, fid::Int) where T
        he = new{T}()
        he.e = e
        he.fid = fid

        return he
    end
    HE{T}() where T = new{T}()
end
twin(he::HE) = he.t
next(he::HE) = he.next
prev(he::HE) = he.prev
function show(io::IO, he::HE)
    print(io, he.e)
end

struct Face{T}
    id::Int
    components::Vector{HE{T}}
end

Face{T}(id) where T = Face{T}(id, HE{T}[])

struct DCEL{T}
    faces::Vector{Face{T}}
    origins::Vector{Pair{V{T}, HE{T}}}
end
function show(io::IO, dcel::DCEL)
    for face in dcel.faces
        println(io, "Face: ", face.id)
        for (i, v0) in enumerate(face.components)
            println(io, "  part: ", i)
            v = v0
            while true
                println(io, v.e)
                v = next(v)
                v.e === v0.e && break
            end
        end
    end
end

DCEL{T}() where T = DCEL{T}(Face{T}[], Pair{V{T}, HE{T}}[])

function DCEL(shape::Shapefile.Polygon, id)
    dcel = DCEL{Float64}()
    face = Face{Float64}(id)
    push!(dcel.faces, face)
    origins = dcel.origins
    points = shape.points
    # I suppose that doing in one loop is more efficient, but doing in two loops is way easier
    offset = 0
    for i in 2:length(points)
        # Weirdly, dcel keep data in counterclockwise direction
        e = HE(E(V(points[i]), V(points[i - 1])), id)
        i == 2 && push!(face.components, e)
        etwin = HE(E(V(points[i - 1]), V(points[i])), -1)
        e.t = etwin
        push!(origins, V(points[i]) => e)
    end
    xlast = length(points) + offset - 1
    xfrst = offset + 1
    for i in xfrst+1:xlast-1
        origins[i][2].next = origins[i - 1][2]
        origins[i][2].prev = origins[i + 1][2]
        origins[i][2].t.next = origins[i + 1][2].t
        origins[i][2].t.prev = origins[i - 1][2].t
    end
    origins[xfrst][2].prev = origins[xfrst+1][2]
    origins[xfrst][2].next = origins[xlast][2]
    origins[xlast][2].prev = origins[xfrst][2]
    origins[xlast][2].next = origins[xlast-1][2]

    origins[xfrst][2].t.next = origins[xfrst+1][2].t
    origins[xfrst][2].t.prev = origins[xlast][2].t
    origins[xlast][2].t.next = origins[xfrst][2].t
    origins[xlast][2].t.prev = origins[xlast-1][2].t
    
    return dcel
end
