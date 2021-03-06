export AvgCutPruningAlgo, AvgCutPruner

"""
$(TYPEDEF)

Removes the cuts with lower trust where the trust is: nused / nwith + bonus
where the cut has been used `nused` times amoung `nwith` optimization done with it.
We say that the cut was used if its dual value is nonzero.
It has a bonus equal to `mycutbonus` if the cut was generated using a trial given by the problem using this cut.
If `nwidth` is zero, `nused/nwith` is replaced by `newcuttrust`.
"""
type AvgCutPruningAlgo <: AbstractCutPruningAlgo
    # maximum number of cuts
    maxncuts::Int
    newcuttrust::Float64
    mycutbonus::Float64
    function AvgCutPruningAlgo(maxncuts::Int, newcuttrust=3/4, mycutbonus=1/4)
        new(maxncuts, newcuttrust, mycutbonus)
    end
end

type AvgCutPruner{N, T} <: AbstractCutPruner{N, T}
    # used to generate cuts
    isfun::Bool
    islb::Bool
    A::AbstractMatrix{T}
    b::AbstractVector{T}

    # maximum number of cuts
    maxncuts::Int

    # number of optimization performed
    nwith::Vector{Int}
    # number of times where the cuts have been used
    nused::Vector{Int}
    mycut::Vector{Bool}
    trust::Nullable{Vector{Float64}}
    ids::Vector{Int} # small id means old
    id::Int # current id

    newcuttrust::Float64
    mycutbonus::Float64

    # tolerance to check redundancy between two cuts
    TOL_EPS::Float64

    function AvgCutPruner(sense::Symbol, maxncuts::Int, newcuttrust=3/4, mycutbonus=1/4; tol=1e-6)
        isfun, islb = gettype(sense)
        new(isfun, islb, spzeros(T, 0, N), T[], maxncuts, Int[], Int[], Bool[], nothing, Int[], 0, newcuttrust, mycutbonus, tol)
    end
end

(::Type{CutPruner{N, T}}){N, T}(algo::AvgCutPruningAlgo, sense::Symbol) = AvgCutPruner{N, T}(sense, algo.maxncuts, algo.newcuttrust, algo.mycutbonus)

# COMPARISON
"""Update cuts relevantness after a solver's call returning dual vector `σρ`."""
function updatestats!(man::AvgCutPruner, σρ)
    if ncuts(man) > 0
        man.nwith += 1
        # TODO: dry 1e-6 in CutPruner?
        man.nused[σρ .> 1e-6] += 1
        man.trust = nothing # need to be recomputed
    end
end

function gettrustof(man::AvgCutPruner, nwith, nused, mycut)
    (nwith == 0 ? man.newcuttrust : nused / nwith) + (mycut ? man.mycutbonus : 0)
end
function initialtrust(man::AvgCutPruner, mycut)
    gettrustof(man, 0, 0, mycut)
end
function hastrust(man::AvgCutPruner)
    !isnull(man.trust)
end
function gettrust(man::AvgCutPruner)
    if !hastrust(man)
        trust = man.nused ./ man.nwith
        trust[man.nwith .== 0] = man.newcuttrust
        trust[man.mycut] += man.mycutbonus
        man.trust = trust
    end
    get(man.trust)
end

# CHANGE

function keeponlycuts!(man::AvgCutPruner, K::AbstractVector{Int})
    man.nwith = man.nwith[K]
    man.nused = man.nused[K]
    man.mycut = man.mycut[K]
    _keeponlycuts!(man, K)
end

function replacecuts!(man::AvgCutPruner, K::AbstractVector{Int}, A, b, mycut::AbstractVector{Bool})
    man.nwith[K] = 0
    man.nused[K] = 0
    man.mycut[K] = mycut
    _replacecuts!(man, K, A, b)
    if hastrust(man)
        get(man.trust)[K] = initialtrusts(man, mycut)
    end
end

function appendcuts!(man::AvgCutPruner, A, b, mycut::AbstractVector{Bool})
    n = length(mycut)
    append!(man.nwith, zeros(n))
    append!(man.nused, zeros(n))
    append!(man.mycut, mycut)
    _appendcuts!(man, A, b)
    if hastrust(man)
        append!(get(man.trust), initialtrusts(man, mycut))
    end
end
