"Majorize-Minimize Algorithm"
type MM <: Algorithm
    η::Float64
    weighting::LearningRate
    function MM(;η::Real = 1.0, kw...)
        @assert η > 0
        new(Float64(η), LearningRate(;kw...))
    end
end

weight(alg::MM) = alg.η * weight(alg.weighting)

Base.show(io::IO, o::MM) = print(io, "MM with rate γ_t = $(o.η) / (1 + $(o.weighting.λ) * t) ^ $(o.weighting.r)")


function updateβ!(o::StochasticModel{MM}, x::AVecF, y::Float64)
    ŷ = predict(o, x)
    γ = weight(o.algorithm)

    if o.intercept
        o.β0 -= γ * mm_grad(o.model, γ, 1.0, y, ŷ)
    end

    for j in 1:length(x)
        o.β[j] += x[j] * mm_grad(o.model, γ, x, y, ŷ)
    end
end

function updatebatchβ!(o::StochasticModel{MM}, x::AMatF, y::AVecF)
    n = length(y)
    γ = weight(o.algorithm) / n

    for i in 1:n
        xi = rowvec_view(x, i)
        g = ∇f_mm(o.model, xi, y[i], predict(o, xi))

        if o.intercept
            o.β0 += γ * g
        end

        for j in 1:size(x, 2)
            o.β[j] += γ * xi[j] * g
        end
    end
end

function ∇f_mm(::LogisticRegression, x::AVecF, y::Float64, ŷ::Float64)
     (y - ŷ) / (sumabs2(x) * ŷ * (1 - ŷ))
end

function ∇f_mm(::PoissonRegression, x::AVecF, y::Float64, ŷ::Float64)
     (y - ŷ) / (sumabs2(x) * ŷ)
end

function ∇f_mm(::L2Regression, x::AVecF, y::Float64, ŷ::Float64)
     (y - ŷ) / sumabs2(x)
end

function ∇f_mm(m::ModelDefinition, γ::Float64, x::AVecF, y::Float64, ŷ::Float64)
    error("This algorithm is not implemented for model: ", typeof(m))
end





# TEST
if true
    srand(10)
    n, p = 1_000_000, 5
    x = randn(n, p)
    β = collect(linspace(0, 1, p))
    # y = x*β + randn(n)
    y = Float64[rand(Bernoulli(1 / (1 + exp(-xb)))) for xb in x*β]
    # y = Float64[rand(Poisson(exp(xb))) for xb in x*β]

    o = StochasticModel(p, algorithm = MM(r=.6), model = LogisticRegression())
    @time update!(o, x, y, 50)
    show(o)

    o = StochasticModel(p, algorithm = SGD(r=.6), model = LogisticRegression())
    @time update!(o, x, y, 50)
    show(o)
end