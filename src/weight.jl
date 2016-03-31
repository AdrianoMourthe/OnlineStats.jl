abstract Weight
nobs(w::Weight) = w.n
weight!(o::OnlineStat, n2::Int = 1) = weight!(o.weight, n2)
weight_noret!(o::OnlineStat, n2::Int = 1) = weight_noret!(o.weight, n2)


"""
`EqualWeight()`.  All observations weighted equally.
"""
type EqualWeight <: Weight
    n::Int
    EqualWeight() = new(0)
end
weight!(w::EqualWeight, n2::Int = 1)        = (w.n += n2; return n2 / w.n)
weight_noret!(w::EqualWeight, n2::Int = 1)  = (w.n += n2)


"""
`ExponentialWeight(λ::Float64)`, `ExponentialWeight(lookback::Int)`

Weights are held constant at `λ = 2 / (1 + lookback)`.
"""
type ExponentialWeight <: Weight
    λ::Float64
    n::Int
    function ExponentialWeight(λ::Real, n::Integer)
        @assert 0 <= λ <= 1
        new(λ, n)
    end
    ExponentialWeight(λ::Real = 1.0) = ExponentialWeight(λ, 0)
    ExponentialWeight(lookback::Integer) = ExponentialWeight(2.0 / (lookback + 1))
end
weight!(w::ExponentialWeight, n2::Int = 1)  = (w.n += n2; w.λ)
weight_noret!(w::ExponentialWeight, n2::Int = 1) = (w.n += n2)


"""
User-defined weights
"""
type UserWeight <: Weight
    w::Float64      # most recent weight
    denom::Float64  # sum of weights
    n::Int
    UserWeight() = new(1., 0., 0)
    UserWeight(w::Real) = new(w, 0., 0)
end
function weight!(o::UserWeight, n2::Int = 1)
    o.n += n2
    o.denom += o.w
    o.w / o.denom
end
weight_noret!(w::UserWeight, n2::Int = 1) = (o.denom += o.w; w.n += n2)
fit!(o::UserWeight, w::Real) = (o.w = w)
function check_user_weight(o::OnlineStat)
    @assert typeof(o.weight) == UserWeight
        "Weight vectors can only be supplied when using UserWeight"
end


"""
`BoundedExponentialWeight(λ::Float64)`, `BoundedExponentialWeight(lookback::Int)`

Use equal weights until reaching `λ = 2 / (1 + lookback)`, then hold constant.
"""
type BoundedExponentialWeight <: Weight
    λ::Float64
    n::Int
    function BoundedExponentialWeight(λ::Real, n::Integer)
        @assert 0 <= λ <= 1
        new(λ, n)
    end
    BoundedExponentialWeight(λ::Real = 1.0) = BoundedExponentialWeight(λ, 0)
    BoundedExponentialWeight(lookback::Integer) = BoundedExponentialWeight(2.0 / (lookback + 1))
end
weight!(w::BoundedExponentialWeight, n2::Int = 1)  = (w.n += n2; return max(n2 / w.n, w.λ))
weight_noret!(w::BoundedExponentialWeight, n2::Int = 1) = (w.n += n2)


"""
`LearningRate(r = 0.6; minstep = 0.0)`.

Weight at update `t` is `1 / t ^ r`.  When weights reach `minstep`, hold weights constant.  Compare to `LearningRate2`.
"""
type LearningRate <: Weight
    r::Float64
    minstep::Float64
    n::Int
    nups::Int
    LearningRate(r::Real = 0.6; minstep::Real = 0.0) = new(r, minstep, 0, 0)
end
function weight!(w::LearningRate, n2::Int = 1)
    w.n += n2
    w.nups += 1
    max(w.minstep, exp(-w.r * log(w.nups)))
end
weight_noret!(w::LearningRate, n2::Int = 1) = (w.n += n2; w.nups += 1)
nups(w::LearningRate) = w.nups


"""
`LearningRate2(γ, c = 1.0; minstep = 0.0)`.

Weight at update `t` is `γ / (1 + γ * c * t)`.  When weights reach `minstep`, hold weights constant.  Compare to `LearningRate`.
"""
type LearningRate2 <: Weight
    # Recommendation from http://research.microsoft.com/pubs/192769/tricks-2012.pdf
    γ::Float64
    c::Float64
    minstep::Float64
    n::Int
    nups::Int
    LearningRate2(γ::Real, c::Real = 1.0; minstep = 0.0) = new(γ, c, minstep, 0, 0)
end
function weight!(w::LearningRate2, n2::Int = 1)
    w.n += n2
    w.nups += 1
    max(w.minstep, w.γ / (1.0 + w.γ * w.c * w.nups))
end
weight_noret!(w::LearningRate2, n2::Int = 1) = (w.n += n2; w.nups += 1)
nups(w::LearningRate2) = w.nups

nups(o::OnlineStat) = nups(o.w)
