# indexnotation/tensormacro.jl
#
# Defines the @tensor macro which switches to an index-notation environment.

macro tensor(ex)
    tensorify(ex)
end


macro tensoropt(args...)
    ex = args[end];
    if isa(args[1],Symbol)
        polycost = processpolycost(args[2:end-1],args[1])
        defaultpoly = Power(1,1)
        optmul(ex,polycost,default)
    else
        numcost = processnumcost(args[1:end])
        defaultnum = 1
        optmul(ex,numcost,defaultnum)
    end
    ex = optmul(ex,cost)
    tensorify(ex)
end

function processpolycost(args,var)
    cost=Dict{Any,Power{Int}}()
    for i = 1:length(args)
        ex = args[i]
        isa(ex,Expr) && ex.head==:(=>) || error("invalid cost specification")
        c = evalpolyex(ex.args[2],var)
        isa(c,Power{Int}) || error("only costs a*$var^n are supported with a::Int")
        l = ex.args[1]
        if isa(l,Symbol) || isa(l,Char) || isa(l,Number)
            cost[l] = c
        elseif isa(l,Expr) && l.head==:tuple
            for s in l.args
                if isa(s,Symbol) || isa(s,Char) || isa(s,Number)
                    cost[s] = c
                else
                    error("invalid cost specification")
                end
            end
        else
            error("invalid cost specification")
        end
    end
    return cost
end



function tensorify(ex::Expr)
    if ex.head == :(=) || ex.head == :(:=) || ex.head == :(+=) || ex.head == :(-=)
        lhs = ex.args[1]
        rhs = ex.args[2]
        if isa(lhs, Expr) && lhs.head == :ref
            dst = tensorify(lhs.args[1])
            src = ex.head == :(-=) ? tensorify(Expr(:call,:-,rhs)) : tensorify(rhs)
            indices = makeindex_expr(lhs)
            if ex.head == :(:=)
                return :($dst = deindexify($src, $indices))
            else
                value = ex.head == :(=) ? 0 : +1
                return :(deindexify!($dst, $src, $indices, $value))
            end
        end
    end
    if ex.head == :ref
        indices = makeindex_expr(ex)
        t = tensorify(ex.args[1])
        return :(indexify($t,$indices))
    end
    if ex.head == :call && ex.args[1] == :scalar
        if length(ex.args) != 2
            error("scalar accepts only a single argument")
        end
        src = tensorify(ex.args[2])
        indices = :(Indices{()}())
        return :(scalar(deindexify($src, $indices)))
    end
    return Expr(ex.head,map(tensorify,ex.args)...)
end
tensorify(ex::Symbol) = esc(ex)
tensorify(ex) = ex

function makeindex_expr(ex::Expr)
    if ex.head == :ref
        for i = 2:length(ex.args)
            isa(ex.args[i],Int) || isa(ex.args[i],Symbol) || isa(ex.args[i],Char) || error("cannot make indices from $ex")
        end
    else
        error("cannot make indices from $ex")
    end
    return :(Indices{$(tuple(ex.args[2:end]...))}())
end
