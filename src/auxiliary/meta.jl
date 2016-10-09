# auxiliary/meta.jl
#
# A bunch of auxiliary metaprogramming tools and generated functions
import Base.tail

_indmax(values::Tuple) = __indmax(values[1],1,1,tail(values))
@inline __indmax(vmax,imax,i,::Tuple{}) = imax
@inline __indmax(vmax,imax,i,values::Tuple) = vmax > values[1] ? __indmax(vmax,imax,i+1,tail(values)) : __indmax(values[1],i+1,i+1,tail(values))

_permute(src::Tuple, p) = __permute((), src, p)
@inline __permute{N}(dst::NTuple{N}, src::NTuple{N}, p) = dst
@inline __permute{N}(dst::NTuple{N}, src::Tuple, p) = @inbounds return __permute(tuple(dst...,src[p[N+1]]), src, p)

_memjumps{N}(dims::NTuple{N,Int},strides::NTuple{N,Int}) = __memjumps((), dims, strides)
@inline __memjumps{N}(jumps::NTuple{N}, dims::NTuple{N}, strides::NTuple{N}) = jumps
@inline __memjumps{N}(jumps::NTuple{N}, dims::Tuple, strides::Tuple) = @inbounds return __memjumps(tuple(jumps...,(dims[N+1]-1)*strides[N+1]), dims, strides)

_select(src::Tuple, sel::Tuple{Vararg{Int}}) = __select((), src, sel)
@inline __select{N}(dst::NTuple{N}, src, sel::NTuple{N}) = dst
@inline __select{N}(dst::NTuple{N}, src, sel) = @inbounds return __select(tuple(dst...,src[sel[N+1]]), src, sel)

# Based on Tim Holy's Cartesian
function _sreplace(ex::Expr, s::Symbol, v)
    Expr(ex.head,[_sreplace(a, s, v) for a in ex.args]...)
end
_sreplace(ex::Symbol, s::Symbol, v) = ex == s ? v : ex
_sreplace(ex, s::Symbol, v) = ex

macro dividebody(N, dmax, dims, args...)
    esc(_dividebody(N, dmax, dims, args...))
end

function _dividebody(N::Int, dmax::Symbol, dims::Symbol, args...)
    mod(length(args),2)==0 || error("Wrong number of arguments")
    argiter = 1:2:length(args)-2

    ex = Expr(:block)
    newdims = gensym(:newdims)
    newdim = gensym(:newdim)
    mainex1 = _sreplace(args[end-1], dims, newdims)
    mainex2 = _sreplace(args[end], dims, newdims)

    for d = 1:N
        updateex = Expr(:block,[:($(args[i]) += $newdim*$(args[i+1]).strides[$d]) for i in argiter]...)
        newdimsex = Expr(:tuple,[Expr(:ref,dims,i) for i=1:d-1]..., newdim, [Expr(:ref,dims,i) for i=d+1:N]...)
        body = quote
            $newdim = $dims[$d] >> 1
            $newdims = $newdimsex
            $mainex1
            $updateex
            $newdim = $dims[$d] - $newdim
            $newdims = $newdimsex
            $mainex2
        end
        ex = Expr(:if,:($dmax == $d), body,ex)
    end
    ex
end

macro stridedloops(N, dims, args...)
    esc(_stridedloops(N, dims, args...))
end
function _stridedloops(N::Int, dims::Symbol, args...)
    mod(length(args),3)==1 || error("Wrong number of arguments")
    argiter = 1:3:length(args)-1
    body = args[end]
    pre = [Expr(:(=), args[i], Symbol(args[i],0)) for i in argiter]
    ex = Expr(:block, pre..., body)
    for d = 1:N
        pre = [Expr(:(=), Symbol(args[i], d-1), Symbol(args[i], d)) for i in argiter]
        post = [Expr(:(+=), Symbol(args[i], d), Expr(:ref, args[i+2], d)) for i in argiter]
        ex = Expr(:block, pre..., ex, post...)
        rangeex = Expr(:(:), 1, Expr(:ref, dims, d))
        forex = Expr(:(=), gensym(), rangeex)
        ex = Expr(:for, forex, ex)
        if d==1
            ex = Expr(:macrocall, Symbol("@simd"), ex)
        end
    end
    pre = [Expr(:(=),Symbol(args[i],N),args[i+1]) for i in argiter]
    ex = Expr(:block, pre..., ex)
end
