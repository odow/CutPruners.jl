export DecayCutPruningAlgo, DecayCutPruner

"""
$(TYPEDEF)

Removes the cuts with lower trust where the trust is initially
`newcuttrust + bonus` and is updated using `trust -> λ * trust + used`
after each optimization done with it.
The value `used` is 1 if the cut was used and 0 otherwise.
It has a bonus equal to `mycutbonus` if the cut was generated using a trial
given by the problem using this cut.
We say that the cut was used if its dual value is nonzero.
"""
type DecayCutPruningAlgo <: AbstractCutPruningAlgo
    maxncuts::Int
    λ::Float64
    newcuttrust::Float64
    mycutbonus::Float64
    function DecayCutPruningAlgo(maxncuts::Int, λ=0.9, newcuttrust=0.8, mycutbonus=1)#newcuttrust=(1/(1/0.9-1))/2, mycutbonus=(1/(1/0.9-1))/2)
        new(maxncuts, λ, newcuttrust, mycutbonus)
    end
end

type DecayCutPruner{N, T} <: AbstractCutPruner{N, T}
    # used to generate cuts
    isfun::Bool
    islb::Bool
    A::AbstractMatrix{T}
    b::AbstractVector{T}

    maxncuts::Int

    trust::Vector{Float64}
    ids::Vector{Int}
    id::Int

    λ::Float64
    newcuttrust::Float64
    mycutbonus::Float64

    # tolerance to check redundancy between two cuts
    TOL_EPS::Float64

    function DecayCutPruner(sense::Symbol, maxncuts::Int, λ=0.9, newcuttrust=0.8, mycutbonus=1, tol=1e-6)#newcuttrust=(1/(1/0.9-1))/2, mycutbonus=(1/(1/0.9-1))/2)
        isfun, islb = gettype(sense)
        new(isfun, islb, spzeros(T, 0, N), T[], maxncuts, Float64[], Int[], 0, λ, newcuttrust, mycutbonus, tol)
    end
end

(::Type{CutPruner{N, T}}){N, T}(algo::DecayCutPruningAlgo, sense::Symbol) = DecayCutPruner{N, T}(sense, algo.maxncuts, algo.λ, algo.newcuttrust, algo.mycutbonus)

# COMPARISON

function updatestats!(man::DecayCutPruner, σρ)
    if ncuts(man) > 0
        man.trust *= man.λ
        man.trust[σρ .> 1e-6] += 1
    end
end

function initialtrust(man::DecayCutPruner, mycut)
    if mycut
        man.newcuttrust + man.mycutbonus
    else
        man.newcuttrust
    end
end

function isbetter(man::DecayCutPruner, i::Int, mycut::Bool)
    if mycut
        # If the cut has been generated, that means it is useful
        false
    else
        # The new cut has initial trust initialtrust(man, false)
        # but it is a bit disadvantaged since it is new so
        # as we advantage the new cut if mycut == true,
        # we advantage this cut by taking initialtrust(man, true)
        # with true instead of false
        man.trust[i] > initialtrust(man, mycut)
    end
end
