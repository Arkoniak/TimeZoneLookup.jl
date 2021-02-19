using TimeZoneLookup
using Documenter

DocMeta.setdocmeta!(TimeZoneLookup, :DocTestSetup, :(using TimeZoneLookup); recursive=true)

makedocs(;
    modules=[TimeZoneLookup],
    authors="Andrey Oskin",
    repo="https://github.com/Arkoniak/TimeZoneLookup.jl/blob/{commit}{path}#{line}",
    sitename="TimeZoneLookup.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://Arkoniak.github.io/TimeZoneLookup.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/Arkoniak/TimeZoneLookup.jl",
)
