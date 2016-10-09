# auxiliary/stridedarray.jl
#
# Simple auxiliary methods to interface with StridedArray from Julia Base.

"""`numind(A)`

Returns the number of indices of a tensor-like object `A`, i.e. for a multidimensional array (`<:AbstractArray`) we have `numind(A) = ndims(A)`. Also works in type domain.
"""
numind(A::AbstractArray) = ndims(A)
numind{T<:AbstractArray}(::Type{T}) = ndims(T)

"""`similar_from_indices(A, inds, T=eltype(A), conjA=Val{:N})`

Returns an object similar to `A` which has an `eltype` given by `T` and dimensions/sizes corresponding to a selection of those of `op(A)`, where the selection is specified by `indices` (which contains integer between `1` and `numind(A)`) and `op` is `conj` if `conjA=Val{:C}` or does nothing if `conjA=Val{:N}` (default).
"""
function similar_from_indices{T,CA}(A::AbstractArray, inds::Tuple, ::Type{T}=eltype(A), ::Type{Val{CA}}=Val{:N})
    newinds = _select(Base.indices(A), inds)
    return similar(A, T, newinds)
end

"""`similar_from_indices(A, B, indices, T=promote_type(eltype(A),eltype(B)) conjA=Val{:N}, conjB={:N})`

Returns an object similar to `A` which has an `eltype` given by `T` and dimensions/sizes corresponding to a selection of those of `op(A)` and `op(B)` concatenated, where the selection is specified by `indices` (which contains integers between `1` and `numind(A)+numind(B)` and `op` is `conj` if `conjA` or `conjB` equal `Val{:C}` or does nothing if `conjA` or `conjB` equal `Val{:N}` (default).
"""
function similar_from_indices{T,CA,CB}(A::AbstractArray, B::AbstractArray, inds::Tuple, ::Type{T}=promote_type(eltype(A),eltype(B)), ::Type{Val{CA}}=Val{:N}, ::Type{Val{CB}}=Val{:N})
    newinds = _select(tuple(Base.indices(A)...,Base.indices(B)...), inds)
    return similar(A,T,newinds)
end

"""`scalar(C)`

Returns the single element of a tensor-like object with zero dimensions, i.e. if `numind(C)==0`.
"""
scalar(C::AbstractArray) = numind(C)==0 ? C[1] : throw(DimensionMismatch())
