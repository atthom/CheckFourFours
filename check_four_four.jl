using IterTools
using Distributed

N = 5
op = [:+, :-, :*, :/, :^]
fun = [:sqrt, :factorial]


function perform(all_values)
    push!(all_values, N)
    push!(all_values, 10*N + N)
    ll = length(all_values)
    size_op = length(op) * ll^2
    size_fun = ll * length(fun)

    all_op = Iterators.product(op, all_values, all_values)
    all_fun = Iterators.product(fun, all_values)

    all_exprs = Vector{Any}(undef, size_op + size_fun)

    #for (i, t) in enumerate(all_values)
    #    all_exprs[i] = all_values[i]
    #end

    for (i, t) in enumerate(all_op)
        all_exprs[i] = Expr(:call, t...)
    end

    for (i, t) in enumerate(all_fun)
        all_exprs[size_op + i] = Expr(:call, t...)
    end

    return all_exprs
end


function expands(expr::Expr)
    args = []
    for a in expr.args
        if typeof(a) == Expr
            args = [args..., expands(a)...]
        else
            push!(args, a)
        end
    end
    return args 
end

count_val(val, expr::Expr) = count(i -> i == val, expands(expr))
count_N(expr::Expr) = count_val(N, expr) + 2*count_val(N*10 + N, expr)

lessThanN(expr::Expr) = count_N(expr) <= N

equal_N(expr::Expr) = count_N(expr) == N


function factorial_div_sqrt(expr::Expr)
    if expr.args[1] != :factorial
        return true
    else
        expr_vals = expands(expr)
        return !(any(f -> f == :/, expr_vals) || any(f -> f == :sqrt, expr_vals))
    end
end

function pow_negative_big(expr::Expr)
    if expr.args[1] != :^
        return true
    else
        return (eval(expr.args[2]) >= 0) && (0 <= eval(expr.args[3]) <= 16)
    end
end

function sqrt_fact_negative(expr::Expr)
    if !in(expr.args[1], [:sqrt, :factorial])
        return true
    else
        return eval(expr.args[2]) >= 0
    end
end 

function big_factorials(expr::Expr)
    if expr.args[1] != :factorial
        return true
    else
        return eval(expr.args[2]) < 20
    end
end

function reduce_equivalents(expr_vals)
    dd = Dict()
    for (value, expr) in expr_vals
        if haskey(dd, value)
            push!(dd[value], expr)
        else
            dd[value] = [expr]
        end
    end

    new_expr_vals = []
    for (val, li_expr) in dd
        nb_n_done = []
        for expr in li_expr
            nb_n = count_N(expr)
            if !in(nb_n, nb_n_done)
                push!(new_expr_vals, (val, expr))
                push!(nb_n_done, nb_n)
            end
        end
    end

    return new_expr_vals
end

no_pow_mul(expr::Expr) = !in(expr.args[2], [:*, :^])
no_sqrt(expr::Expr) = !in(expr.args[1], [:sqrt])
two_add(expr::Expr) = count(i -> i == :+, expands(expr)) == 2
no_55(expr::Expr) = count(i -> i == 55, expands(expr)) == 0

function reduce_expr(all_values)
    for expr in all_values
        for (idx, sub) in enumerate(expr.args)
            if typeof(sub) == Expr
                expr.args[idx] = eval(sub)
                print( expr.args[idx])
            end
        end
    end
    return  all_values
end
# (factorial(5) - 5)
function main(number)
    all_values = []
    for i = 1:4
        all_values = perform(all_values)
        #println(all_values)

        #all_values = reduce_expr(all_values)

        all_values = Iterators.filter(lessThanN, all_values)
        all_values = Iterators.filter(factorial_div_sqrt, all_values)
        all_values = Iterators.filter(big_factorials, all_values)
        all_values = Iterators.filter(sqrt_fact_negative, all_values)
        all_values = Iterators.filter(pow_negative_big, all_values)

        ### to remove
        all_values = Iterators.filter(no_pow_mul, all_values)
        all_values = Iterators.filter(no_55, all_values)
        all_values = Iterators.filter(no_sqrt, all_values)
        
        if i == 4
            all_values = Iterators.filter(two_add, all_values)
        end
        ##

        expr_vals = map(expr -> (eval(expr), expr), all_values)
        expr_vals = filter(item -> -1000 < item[1] < 1000, expr_vals)
        expr_vals = reduce_equivalents(expr_vals)
        
        all_exprs = []
        for (value, expr) in expr_vals
            if eval(expr) == number && equal_N(expr)
                return expr
            end
            push!(all_exprs, expr)
        end
        all_values = all_exprs # map(item -> item[2], expr_vals)
        if i == 4
            println(all_values)
        else
            println(length(all_values))
        end
    end
end

#for i = 34:60
#    expr = main(i)
#    println(eval(expr),": ", expr)
#end
