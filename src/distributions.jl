#---------------------------------------------------------------------------------# Beta
"""
```julia
FitBeta()
```
Online parameter estimate of a Beta distribution (Method of Moments)
### Example
```julia
using Distributions, OnlineStats
y = rand(Beta(3, 5), 1000)
s = Series(y, FitBeta())
Beta(value(s)...)
```
"""
struct FitBeta <: OnlineStat{0, 1, EqualWeight}
    var::Variance
    FitBeta() = new(Variance())
end
fit!(o::FitBeta, y::Real, γ::Float64) = fit!(o.var, y, γ)
function _value(o::FitBeta)
    if o.var.nobs > 1
        m = mean(o.var)
        v = var(o.var)
        α = m * (m * (1 - m) / v - 1)
        β = (1 - m) * (m * (1 - m) / v - 1)
        return α, β
    else
        return 1.0, 1.0
    end
end
#---------------------------------------------------------------------------------# Categorical
"""
    FitCategorical(T)
Fit a categorical distribution where the inputs are of type `T`.
# Example
    using Distributions
    s = Series(rand(1:10, 1000), FitCategorical(Int))
    value(s)

    vals = ["small", "medium", "large"]
    s = Series(rand(vals, 1000), FitCategorical(String))
    value(s)
"""
mutable struct FitCategorical{T<:Any} <: OnlineStat{0, 1, EqualWeight}
    d::Dict{T, Int}
    nobs::Int
    FitCategorical{T}() where T<:Any = new(Dict{T, Int}(), 0)
end
FitCategorical(t::Type) = FitCategorical{t}()
function fit!{T}(o::FitCategorical{T}, y::T, γ::Float64)
    o.nobs += 1
    haskey(o.d, y) ? (o.d[y] += 1) : (o.d[y] = 1)
end
_value(o::FitCategorical) = ifelse(o.nobs > 0, collect(values(o.d)) ./ o.nobs, zeros(0))
Base.keys(o::FitCategorical) = keys(o.d)
#---------------------------------------------------------------------------------# Cauchy
"""
```julia
FitCauchy()
```
Online parameter estimate of a Cauchy distribution
### Example
```julia
using Distributions
y = rand(Cauchy(0, 10), 10_000)
s = Series(y, FitCauchy())
Cauchy(value(s)...)
```
"""
mutable struct FitCauchy <: OnlineStat{0, 1, LearningRate}
    q::QuantileMM
    nobs::Int
    FitCauchy() = new(QuantileMM(), 0)
end
fit!(o::FitCauchy, y::Real, γ::Float64) = (o.nobs += 1; fit!(o.q, y, γ))
function _value(o::FitCauchy)
    if o.nobs > 1
        return o.q.value[2], 0.5 * (o.q.value[3] - o.q.value[1])
    else
        return 0.0, 1.0
    end
end
#---------------------------------------------------------------------------------# Gamma
"""
```julia
FitGamma()
```
Online parameter estimate of a Gamma distribution (Method of Moments)
### Example
```julia
using Distributions
y = rand(Gamma(5, 1), 1000)
s = Series(y, FitGamma())
Gamma(value(s)...)
```
"""
# method of moments. TODO: look at Distributions for MLE
struct FitGamma <: OnlineStat{0, 1, EqualWeight}
    var::Variance
end
FitGamma() = FitGamma(Variance())
fit!(o::FitGamma, y::Real, γ::Float64) = fit!(o.var, y, γ)
function _value(o::FitGamma)
    if o.var.nobs > 1
        m = mean(o.var)
        v = var(o.var)
        θ = v / m
        α = m / θ
        return α, θ
    else
        return 1.0, 1.0
    end
end
#---------------------------------------------------------------------------------# LogNormal
"""
```julia
FitLogNormal()
```
Online parameter estimate of a LogNormal distribution (MLE)
### Example
```julia
using Distributions
y = rand(LogNormal(3, 4), 1000)
s = Series(y, FitLogNormal())
LogNormal(value(s)...)
```
"""
struct FitLogNormal <: OnlineStat{0, 1, EqualWeight}
    var::Variance
    FitLogNormal() = new(Variance())
end
fit!(o::FitLogNormal, y::Real, γ::Float64) = fit!(o.var, log(y), γ)
function _value(o::FitLogNormal)
    if o.var.nobs > 1
        return mean(o.var), std(o.var)
    else
        return 0.0, 1.0
    end
end
#---------------------------------------------------------------------------------# Normal
"""
```julia
FitNormal()
```
Online parameter estimate of a Normal distribution (MLE)
### Example
```julia
using Distributions
y = rand(Normal(-3, 4), 1000)
s = Series(y, FitNormal())
```
"""
struct FitNormal <: OnlineStat{0, 1, EqualWeight}
    var::Variance
    FitNormal() = new(Variance())
end
fit!(o::FitNormal, y::Real, γ::Float64) = fit!(o.var, y, γ)
function _value(o::FitNormal)
    if o.var.nobs > 1
        return mean(o.var), std(o.var)
    else
        return 0.0, 1.0
    end
end
#---------------------------------------------------------------------------------# Multinomial
# TODO: Allow each observation to have a different n
"""
```julia
FitMultinomial(p)
```
Online parameter estimate of a Multinomial distribution.
### Example
```julia
using Distributions
y = rand(Multinomial(10, [.2, .2, .6]), 1000)
s = Series(y', FitMultinomial())
Multinomial(value(s)...)
```
"""
mutable struct FitMultinomial <: OnlineStat{1, 1, EqualWeight}
    mvmean::MV{Mean}
    nobs::Int
    FitMultinomial(p::Integer) = new(MV(p, Mean()), 0)
end
function fit!{T<:Real}(o::FitMultinomial, y::AVec{T}, γ::Float64)
    o.nobs += 1
    fit!(o.mvmean, y, γ)
    o
end
function _value(o::FitMultinomial)
    m = value(o.mvmean)
    p = length(o.mvmean.stats)
    if o.nobs > 0
        return 1, m / sum(m)
    else
        return 1, ones(p) / p
    end
end
#---------------------------------------------------------------------------------# MvNormal
"""
```julia
FitMvNormal(d)
```
Online parameter estimate of a `d`-dimensional MvNormal distribution (MLE)
### Example
```julia
using Distributions
y = rand(MvNormal(zeros(3), eye(3)), 1000)
s = Series(y', FitMvNormal(3))
```
"""
struct FitMvNormal<: OnlineStat{1, (1, 2), EqualWeight}
    cov::CovMatrix
    FitMvNormal(p::Integer) = new(CovMatrix(p))
end
Base.length(o::FitMvNormal) = length(o.cov)
fit!{T<:Real}(o::FitMvNormal, y::AVec{T}, γ::Float64) = fit!(o.cov, y, γ)
function _value(o::FitMvNormal)
    c = cov(o.cov)
    if isposdef(c)
        return mean(o.cov), c
    else
        return zeros(length(o)), eye(length(o))
    end
end
