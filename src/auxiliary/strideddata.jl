# auxiliary/strideddata.jl
#
# Wrapper to group data (as vector indicating a memory region), a starting offset
# inside the region and a collection of strides to interpret this memory as a
# multidimensional array.

immutable StridedData{N,T,C}
    data::Vector{T}
    strides::NTuple{N,Int}
    start::Int
end
typealias NormalStridedData{N,T} StridedData{N,T,:N}
typealias ConjugatedStridedData{N,T} StridedData{N,T,:C}

typealias StridedSubArray{T,N,A<:Array,I<:Tuple{Vararg{Union{Colon,Range{Int64},Int64}}},LD} SubArray{T,N,A,I,LD}

StridedData{N,T,C}(a::Array{T}, strides::NTuple{N,Int} = _strides(a), ::Type{Val{C}} = Val{:N}) =
    StridedData{N,T,C}(vec(a), strides, 1)
StridedData{N,T,C}(a::StridedSubArray{T}, strides::NTuple{N,Int} = _strides(a), ::Type{Val{C}} = Val{:N}) =
    StridedData{N,T,C}(vec(a.parent), strides, Base.first_index(a))

Base.getindex(a::NormalStridedData,i) = a.data[i]
Base.getindex(a::ConjugatedStridedData,i) = conj(a.data[i])

Base.setindex!(a::NormalStridedData,v,i) = (@inbounds a.data[i] = v)
Base.setindex!(a::ConjugatedStridedData,v,i) = (@inbounds a.data[i] = conj(v))

# set dimensions dims[d]==1 for all d where a.strides[d] == 0.
@generated function _filterdims{N}(dims::NTuple{N,Int}, a::StridedData{N})
    meta = Expr(:meta,:inline)
    ex = Expr(:tuple,[:(a.strides[$d]==0 ? 1 : dims[$d]) for d=1:N]...)
    Expr(:block,meta,ex)
end

# initial scaling of a block specified by dims
_scale!{N}(C::StridedData{N}, β::One, dims::NTuple{N,Int}, offset::Int=0) = C

@generated function _scale!{N}(C::StridedData{N}, β::Zero, dims::NTuple{N,Int}, offset::Int=0)
    meta = Expr(:meta,:inline)
    quote
        $meta
        dims = _filterdims(dims,C)
        startC = C.start+offset
        stridesC = C.strides
        @stridedloops($N, dims, indC, startC, stridesC, @inbounds C[indC] = false)
        return C
    end
end

@generated function _scale!{N}(C::StridedData{N}, β::Number, dims::NTuple{N,Int}, offset::Int=0)
    meta = Expr(:meta,:inline)
    quote
        $meta
        dims = _filterdims(dims,C)
        startC = C.start+offset
        stridesC = C.strides
        @stridedloops($N, dims, indC, startC, stridesC, @inbounds C[indC] *= β)
        return C
    end
end
