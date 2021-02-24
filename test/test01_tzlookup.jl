module TZLookup

using TimeZoneLookup
using Test

@testset "update!" begin
    S = [EData(E(V(10, 10), V(30, 10)), 1, -1),
         EData(E(V(10, 10), V(20, 20)), -1, 1),
         EData(E(V(30, 10), V(40, 20)), 1, -1),
         EData(E(V(20, 20), V(40, 20)), -1, 1)
        ]
    bb = Trapezoid(V(0, 0), V(50, 50), E(V(0, 50), V(50, 50)), E(V(0, 0), V(50, 0)), -1)
    bbdata = TrapezoidData(bb)
    root = TrapezoidalSearchNode(bbdata)
    bbdata.node = root

    s1 = S[2]
    update!(root, s1)

    @test query(root, V(5, 15)).t.face == -1
    @test query(root, V(25, 15)).t.face == -1
    @test query(root, V(15, 5)).t.face == 1
    @test query(root, V(15, 25)).t.face == -1
end

end # module
