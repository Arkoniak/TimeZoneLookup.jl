module TZLookup

using TimeZoneLookup
using TimeZoneLookup: buildnode, faceof, E, V
using Test

@testset "faceof" begin
    @test faceof(EData(E(V(0, 0), V(0, 10)), -1, 1), V(5, 5)) == 1
    @test faceof(EData(E(V(0, 0), V(0, 10)), -1, 1), V(-5, 5)) == -1
    @test faceof(EData(E(V(0, 0), V(10, 0)), -1, 1), V(5, 5)) == -1
    @test faceof(EData(E(V(0, 0), V(10, 0)), -1, 1), V(5, -5)) == 1
    @test faceof(EData(E(V(0, 0), V(10, 10)), -1, 1), V(0, 10)) == -1
    @test faceof(EData(E(V(0, 0), V(10, 10)), -1, 1), V(10, 0)) == 1

    @test faceof(EData(E(V(100, 100), V(100, 110)), -1, 1), V(105, 1055)) == 1
    @test faceof(EData(E(V(100, 100), V(100, 110)), -1, 1), V(95, 105)) == -1
    @test faceof(EData(E(V(100, 100), V(110, 100)), -1, 1), V(105, 105)) == -1
    @test faceof(EData(E(V(100, 100), V(110, 100)), -1, 1), V(105, 95)) == 1
    @test faceof(EData(E(V(100, 100), V(110, 110)), -1, 1), V(105, 110)) == -1
    @test faceof(EData(E(V(100, 100), V(110, 110)), -1, 1), V(110, 100)) == 1
end

@testset "update!" begin
    S = [EData(E(V(10, 10), V(30, 10)), 1, -1),
         EData(E(V(10, 10), V(20, 20)), -1, 1),
         EData(E(V(30, 10), V(40, 20)), 1, -1),
         EData(E(V(20, 20), V(40, 20)), -1, 1)
        ]
    bb, root = buildnode(V(0, 0), V(50, 50), E(V(0, 50), V(50, 50)), E(V(0, 0), V(50, 0)), -1)

    update!(root, S[2])

    @test query(root, V(5, 15)).face == -1
    @test query(root, V(25, 15)).face == -1
    @test query(root, V(15, 5)).face == 1
    @test query(root, V(15, 25)).face == -1

    update!(root, S[3])

    @test query(root, V(25, 15)).face == -1
    @test query(root, V(45, 15)).face == -1
    @test query(root, V(35, 10)).face == -1
    @test query(root, V(35, 20)).face == 1
end

end # module
