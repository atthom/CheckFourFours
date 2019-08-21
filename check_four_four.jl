using IterTools
using Distributed

N = 4
op = [:+, :-, :*, :/, :^]
fun = [:sqrt, :factorial]


function perform(all_values)
    push!(all_values, N)
    push!(all_values, N*10 + N)
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

function main(number)
    all_values = []
    for i = 1:N
        all_values = perform(all_values)
        all_values = Iterators.filter(lessThanN, all_values)
        all_values = Iterators.filter(factorial_div_sqrt, all_values)
        all_values = Iterators.filter(big_factorials, all_values)
        all_values = Iterators.filter(sqrt_fact_negative, all_values)
        all_values = Iterators.filter(pow_negative_big, all_values)
        
        expr_vals = pmap(expr -> (eval(expr), expr), all_values)
        new_vals = []
        for (value, expr) in expr_vals
            if eval(expr) == number && equal_N(expr)
                return expr
            end
            if -1000 < value < 1000 && count_N(expr) < N
                push!(new_vals, expr)
            end
        end
        all_values = new_vals
    end
end

for i = 40:60
    expr = main(i)
    println(eval(expr),": ", expr)
end

# 31: ???
# 32: 4 ^ 4 / (4 + 4)
# 33: ???
# 34: factorial(4) + (sqrt(4) + (4 + 4))
# 35: factorial(4) + 44 / 4
# 36: 44 - (4 + 4)
# 37: ???
# 38: (44 - 4) - sqrt(4)
# 39: ??
# 40: 4 * (sqrt(4) + (4 + 4))