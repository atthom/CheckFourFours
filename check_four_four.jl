using IterTools

N = 4
op = [:+, :-, :*, :/, :^]
fun = [:sqrt, :factorial]


function perform(all_values)
    push!(all_values, N)
    push!(all_values, N*10 + N)
    push!(all_values, N*100 + N*10 + N)
    push!(all_values, N*1000 + N*100 + N*10 + N)
    ll = length(all_values)
    size_op = length(op) * ll^2
    size_fun = ll * length(fun)

    all_op = Iterators.product(op, all_values, all_values)
    all_fun = Iterators.product(fun, all_values)

    all_exprs = Vector{Expr}(undef, size_op + size_fun)

    #println(collect(all_op), collect(all_fun))
    #all_values = vcat(collect(all_op)..., collect(all_fun)...)

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
count_N(expr::Expr) = count_val(N, expr) + 2*count_val(N*10 + N, expr) + 3*count_val(N*100 + N*10 + N, expr) + 4*count_val(N*1000 + N*100 + N*10 + N, expr)

lessThanN(expr::Expr) = count_N(expr) <= N

equal_N(expr::Expr) = count_N(expr) == N

function factorial_sqrt(expr::Expr)
    expr_vals = expands(expr)
    return !(any(f -> f == :factorial, expr_vals) && any(f -> f == :sqrt, expr_vals))
end

function factorial_div(expr::Expr)
    expr_vals = expands(expr)
    return !(any(f -> f == :factorial, expr_vals) && any(f -> f == :/, expr_vals))
end

function pow_negative(expr::Expr)
    if expr.args[1] != :^
        return true
    else
        return (eval(expr.args[3]) >= 0) && (eval(expr.args[2]) >= 0)
    end
end 

function big_pow(expr)
    if expr.args[1] != :^
        return true
    else
        return eval(expr.args[3]) <= 16
    end
end

function sqrt_fact_pow_negative(expr::Expr)
    if !(expr.args[1] in [:sqrt, :factorial])
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

function remove_equivalents(all_values)
    #for ep in all_values
    #    println(ep)
    #    eval(ep)
    #end
    expr_vals = map(expr -> (eval(expr), expr), all_values)
    expr_vals = filter(item -> !isinf(item[1]), expr_vals)

    dict_expr = Dict()

    for (value, expr) = expr_vals
        if haskey(dict_expr, value)
            push!(dict_expr[value], expr)
        else
            dict_expr[value] = [expr]
        end
    end

    compressed_vals = []

    for v in values(dict_expr)
        all_nb_N = []

        for expr in v
            nb_N = count_N(expr)
            if !(nb_N in all_nb_N)
                push!(all_nb_N, nb_N)
                push!(compressed_vals, expr)
            end
        end
    end
    return compressed_vals
end

function main(number)
    all_values = []
    for i = 1:N*N
        all_values = perform(all_values)
        all_values = Iterators.filter(lessThanN, all_values)
        all_values = Iterators.filter(factorial_sqrt, all_values)
        all_values = Iterators.filter(factorial_div, all_values)
        all_values = Iterators.filter(big_factorials, all_values)
        all_values = Iterators.filter(sqrt_fact_pow_negative, all_values)
        all_values = Iterators.filter(pow_negative, all_values)
        all_values = Iterators.filter(big_pow, all_values)
        all_values = remove_equivalents(all_values)
        
        for expr in all_values
            if eval(expr) == number && equal_N(expr)
                return expr
            end
        end
    end
end


for i = 1:50
    expr = main(i)
    println(eval(expr),": ", expr)
end