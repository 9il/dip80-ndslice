#!/usr/bin/env dub
/+ dub.sdl:
name "flex_plot_beta"
dependency "flex_common" path="./common"
versions "Flex_logging" "Flex_single"
+/

// a=2, b=5
// https://en.wikipedia.org/wiki/Beta_distribution
// http://www.wolframalpha.com/input/?i=PDF%5BGammaDistribution%5B2,+5%5D%5D
void test(S, F)(in ref F test)
{
    import std.math : log, pow;
    auto f0 = (S x) => cast(S) log(30 * (1 - x).pow(x));
    auto f1 = (S x) => (1 - 5 * x)/(x - x * x);
    auto f2 = (S x) => (-1 + 2 * x - 5 * x * x) / (pow(-1 + x, 2) * x * x);
    S[] points = [0,  1];
    test.plot("dist_beta", f0, f1, f2, 1.5, points);
}

version(Flex_single) void main()
{
    import flex_common;
    alias T = double;
    int n = 5_000;
    string plotDir = "plots";
    T rho = 1.1;
    auto cf = CFlex!T(5_000, plotDir, rho);
    test!(T, typeof(cf))(cf);
}
