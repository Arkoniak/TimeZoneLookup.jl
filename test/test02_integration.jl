module TestIntegration

using TimeZoneLookup
using TimeZoneLookup: V, query
using Setfield
using Combinatorics
using Test

function calcpoints(tree, maxn = 3)
    res = ntuple(i -> 0, maxn)
    for i in 0:50
        for j in 0:50
            face = query(tree, V(i, j)).face
            face == -1 && continue
            @set! res[face] += 1
        end
    end

    return res
end

@testset "Integrations" begin
@testset "Simple parallelogram" begin
    S = [EData(E(V(10, 10), V(30, 10)), 1, -1),
         EData(E(V(10, 10), V(20, 20)), -1, 1),
         EData(E(V(30, 10), V(40, 20)), 1, -1),
         EData(E(V(20, 20), V(40, 20)), -1, 1)
        ]

    for sp in permutations(S)
        tree = buildsearch(sp, V(0, 0), V(50, 50))
        res = calcpoints(tree)
        @test res[1] == 200
    end
end

@testset "Monotonous flag" begin
    S = [EData(E(V(10, 10), V(30, 10)), 1, -1),
         EData(E(V(10, 10), V(15, 15)), -1, 1),
         EData(E(V(11, 20), V(15, 15)), 1, -1),
         EData(E(V(30, 10), V(40, 20)), 1, -1),
         EData(E(V(11, 20), V(40, 20)), -1, 1)
        ]
    for sp in permutations(S)
        tree = buildsearch(sp, V(0, 0), V(50, 50))
        res = calcpoints(tree)
        @test res[1] == 224
    end
end

@testset "Parallelogram with a hole" begin
    S = [EData(E(V(10, 10), V(30, 10)), 1, -1),
         EData(E(V(10, 10), V(20, 40)), -1, 1),
         EData(E(V(30, 10), V(40, 40)), 1, -1),
         EData(E(V(20, 40), V(40, 40)), -1, 1),
         EData(E(V(14, 12), V(20, 18)), 1, -1),
         EData(E(V(14, 12), V(24, 12)), -1, 1),
         EData(E(V(20, 18), V(24, 12)), 1, -1),
        ]
    for sp in permutations(S)
        tree = buildsearch(sp, V(0, 0), V(50, 50))
        res = calcpoints(tree)
        @test res[1] == 571
    end
end

@testset "Two triangles" begin
    S = [EData(E(V(10, 10), V(30, 10)), 1, -1),
         EData(E(V(10, 10), V(20, 40)), -1, 1),
         EData(E(V(20, 40), V(40, 40)), -1, 2),
         EData(E(V(30, 10), V(40, 40)), 2, -1),
         EData(E(V(20, 40), V(30, 10)), 2, 1)
        ]

    for sp in permutations(S)
        tree = buildsearch(sp, V(0, 0), V(50, 50))
        res = calcpoints(tree)
        @test res[1] == 300
        @test res[2] == 300
    end
end

@testset "Degenerate point" begin
    S = [EData(E(V(10, 10), V(20, 40)), -1, 1),
         EData(E(V(20, 40), V(30, 10)), -1, 1),
         EData(E(V(20, 40), V(30, 45)), -1, 1),
         EData(E(V(20, 40), V(40, 40)), 1, -1),
        ]
    for sp in permutations(S)
        tree = buildsearch(sp, V(0, 0), V(50, 50))
        res = calcpoints(tree)
        @test res[1] == 640
    end
end

end

end #module
