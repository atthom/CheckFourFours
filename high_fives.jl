
import Base.Threads.@spawn
@everywhere using IterTools
N = 5
op = [:+, :-, :*, :/, :^]
fun = [:sqrt, :factorial]


@everywhere function create_expr(elem) 
    if isa(elem, Tuple)
        return Expr(:call, [create_expr(e) for e in elem]...)
    else
        return elem
    end
end
#create_expr(t::Tuple) = Expr(:call, [if typeof(x) == Tuple create_expr(x) else x end for x in t]...)

@everywhere function perform(all_values)
    push!(all_values, N)
    push!(all_values, 10*N + N)
    ll = length(all_values)
    size_op = length(op) * ll^2
    size_fun = (ll + size_op) * length(fun)
    #size_fun = size_fun + size_op*length(op)* length(fun)
    size_fun = ll * length(fun)

    all_op = Iterators.product(op, all_values, all_values)
    fun_val = Iterators.product(fun, all_values)
    #fun_op = Iterators.product(fun, all_op)
    #op_fun = Iterators.product(op, all_op, fun)
    #all_op_fun = Iterators.flatten((all_op, fun_val, fun_op, op_fun))
    op_fun = Iterators.flatten((all_op, fun_val))

    all_exprs = Vector{Expr}(undef, size_op + size_fun)

    for (i, t) in enumerate(op_fun)
        all_exprs[i] = create_expr(t)
    end

    return all_exprs
end


@everywhere function expands(expr::Expr)
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

@everywhere count_val(val, expr::Expr) = count(i -> i == val, expands(expr))
@everywhere count_N(expr::Expr) = count_val(N, expr) + 2*count_val(N*10 + N, expr)

@everywhere lessThanN(expr::Expr) = count_N(expr) <= N

@everywhere equal_N(expr::Expr) = count_N(expr) == N


@everywhere function factorial_div_sqrt(expr::Expr)
    if expr.args[1] != :factorial
        return true
    else
        expr_vals = expands(expr)
        return !(any(f -> f == :/, expr_vals) || any(f -> f == :sqrt, expr_vals))
    end
end

@everywhere function pow_negative_big(expr::Expr)
    if expr.args[1] != :^
        return true
    else
        return (eval(expr.args[2]) >= 0) && (0 <= eval(expr.args[3]) <= 16)
    end
end

@everywhere function sqrt_fact_negative(expr::Expr)
    if !in(expr.args[1], [:sqrt, :factorial])
        return true
    else
        expr_vals = expands(expr)
        if any(f -> in(f, [:/, :^, :sqrt]), expr_vals)
            return false
        end
        return eval(expr.args[2]) >= 0
    end
end 

@everywhere function big_factorials(expr::Expr)
    if expr.args[1] != :factorial
        return true
    else
        expr_vals = expands(expr)
        if any(f -> in(f, [:/, :^, :sqrt]), expr_vals)
            return false
        end
        return eval(expr.args[2]) < 20
    end
end

@everywhere function reduce_equivalents(expr_vals)
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

@everywhere no_pow_mul(expr::Expr) = !in(expr.args[2], [:*, :^])
@everywhere no_sqrt(expr::Expr) = !in(expr.args[1], [:sqrt])
@everywhere two_add(expr::Expr) = count(i -> i == :+, expands(expr)) == 2
@everywhere no_55(expr::Expr) = count(i -> i == 55, expands(expr)) == 0

function main(number)
    all_values = [] #[N, 10*N + N]
    for i = 1:N
        all_values = perform(all_values)

        all_values = Iterators.filter(lessThanN, all_values)
        all_values = Iterators.filter(factorial_div_sqrt, all_values)
        all_values = Iterators.filter(big_factorials, all_values)
        all_values = Iterators.filter(sqrt_fact_negative, all_values)
        all_values = Iterators.filter(pow_negative_big, all_values)

        expr_vals = map(expr -> (eval(expr), expr), all_values)
        expr_vals = filter(item -> - N*100 < item[1] < N*100, expr_vals)
        expr_vals = filter(item -> floor(item[1]) == item[1], expr_vals)
        expr_vals = reduce_equivalents(expr_vals)
        
        all_exprs = []
        for (value, expr) in expr_vals
            if eval(expr) == number && equal_N(expr)
                return expr
            end
            push!(all_exprs, expr)
        end
        all_values = all_exprs # map(item -> item[2], expr_vals)
        
    end
end

for i = 60:100
    expr = main(i)
    println(eval(expr),": ", expr)
end
