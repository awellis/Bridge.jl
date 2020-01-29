using Test
using Bridge
using Bridge: expint
using LinearAlgebra

e1taylor(x) = @evalpoly(x,
-0.5772156649015329,
 1.0,
-0.25,
 0.05555555555555555,
-0.010416666666666666,
 0.0016666666666666666,
-0.0002314814814814815,
 2.834467120181406e-5,
-3.1001984126984127e-6,
 3.0619243582206544e-7,
-2.7557319223985888e-8) - log(x)

@test norm(e1taylor(1.0) - 0.21938393439552029) < 1e-8
@test norm(e1taylor(0.6) - 0.4543795031894021) < 1e-11
@test norm(e1taylor(0.05) - 2.467898488509974369559902) < eps()

@test norm(expint(3.0) - 0.013048381094197037) < eps()
@test norm(expint(1.0) - 0.21938393439552029) == 0
@test norm(expint(0.6) - 0.4543795031894021) == 0
@test norm(expint(0.05) - 2.467898488509974369559902)  == 0