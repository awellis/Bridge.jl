
function Bridge.sample!(W::SamplePath{Vector{T}}, P::Wiener{Vector{T}}, y1 = W.yy[1]) where {T}
    y = copy(y1)
    copyto!(W.yy[1], y)

    for i = 2:length(W.tt)
        rootdt = sqrt(W.tt[i]-W.tt[i-1])
        for k in eachindex(y)
            y[k] =  y[k] + rootdt*randn(T)
        end
        copyto!(W.yy[i], y)
    end
    #println(W.yy[1])
    W
end


struct StratonovichHeun! <: Bridge.SDESolver
end

function Bridge.solve!(solver::StratonovichHeun!, Y::SamplePath, u, W::SamplePath, P::Bridge.ProcessOrCoefficients)
    N = length(W)
    N != length(Y) && error("Y and W differ in length.")

    tt = Y.tt
    tt[:] = W.tt
    yy = Y.yy
    y = copy(u)
    ȳ = copy(u)

    tmp1 = copy(y)
    tmp2 = copy(y)
    tmp3 = copy(y)
    tmp4 = copy(y)

    dw = copy(W.yy[1])
    for i in 1:N-1
        t¯ = tt[i]
        dt = tt[i+1] - t¯
        copyto!(yy[i], y)
        if dw isa Number
            dw = W.yy[i+1] - W.yy[i]
        else
            for k in eachindex(dw)
                dw[k] = W.yy[i+1][k] - W.yy[i][k]
            end
        end

        Bridge._b!((i,t¯), y, tmp1, P)
        Bridge.σ!(t¯, y, dw, tmp2, P)

        for k in eachindex(y)
            ȳ[k] = y[k] + tmp1[k]*dt + tmp2[k] # Euler prediction
        end

        Bridge._b!((i + 1,t¯ + dt), ȳ, tmp3, P) # coefficients at ȳ
        #Bridge.σ!(t¯ + dt, ȳ, dw2, tmp4, P)  # original implementation
        Bridge.σ!(t¯ + dt, ȳ, dw, tmp4, P)

        for k in eachindex(y)
            y[k] = y[k] + 0.5*((tmp1[k] + tmp3[k])*dt + tmp2[k] + tmp4[k])
        end
    end
    copyto!(yy[end], Bridge.endpoint(y, P))
    Y
end

function LinearAlgebra.naivesub!(At::Adjoint{<:Any,<:LowerTriangular}, b::AbstractVector, x::AbstractVector = b)
    A = At.parent
    n = size(A, 2)
    if !(n == length(b) == length(x))
        throw(DimensionMismatch("second dimension of left hand side A, $n, length of output x, $(length(x)), and length of right hand side b, $(length(b)), must be equal"))
    end
    @inbounds for j in n:-1:1
        iszero(A.data[j,j]) && throw(SingularException(j))
        xj = x[j] = A.data[j,j] \ b[j]
        for i in j-1:-1:1 # counterintuitively 1:j-1 performs slightly better
            b[i] -= A.data[j,i] * xj
        end
    end
    x
end

function lyapunovpsdbackward_step!(t, dt, Paux,Hend⁺,H⁺)
    B = Matrix(Bridge.B(t - dt/2, Paux))
    ϕ = (I + 1/2*dt*B)\(I - 1/2*dt*B)
    #Ht .= ϕ *(Hend⁺ + 1/2*dt*Bridge.a(t - dt, Paux))* ϕ' + 1/2*dt*Bridge.a(t, Paux)
    H⁺ .= ϕ *(Hend⁺ + 1/2*dt*Bridge.a(t - dt, Paux))* conj!(copy(ϕ)) + 1/2*dt*Bridge.a(t, Paux)
    H⁺
end

"""
Compute transpose of square matrix of Unc matrices

A = reshape([Unc(1:4), Unc(5:8), Unc(9:12), Unc(13:16)],2,2)
B = copy(A)
A
conj!(B)
"""
function conj!(A::Array{StaticArrays.SArray{Tuple{2,2},Float64,2,4},2})
    if !(size(A,1)==size(A,2)) error("conj! only correctly defined for square matrices") end
    for i in 1:size(A,1)
        A[i,i] = A[i,i]'
        for j in (i+1):size(A,2)
                A[i,j], A[j, i] = A[j,i]', A[i, j]'
        end
    end
    A
end
