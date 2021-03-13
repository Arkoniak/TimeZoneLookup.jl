module TestSweep

using TimeZoneLookup
using TimeZoneLookup: V
using Test

@testset "Points comparison" begin
    @test V(1, 2) > V(1, 3)
    @test V(1, 2) < V(2, 2)
end

end
