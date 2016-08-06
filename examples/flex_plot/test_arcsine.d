#!/usr/bin/env dub
/+ dub.sdl:
name "flex_plot_arcsine"
dependency "flex_common" path="./common"
versions "Flex_logging" "Flex_single"
+/

// https://en.wikipedia.org/wiki/Arcsine_distribution
// http://www.wolframalpha.com/input/?i=PDF%5BArcsineDistribution%5B0,+1%5D%5D
void test(S, F)(in ref F test)
{
    import std.math : log, pow, PI, sqrt;
    auto f0 = (S x) => cast(S) (-S(0.5) * log(-(x-1) * x) - log(PI));
    auto f1 = (S x) => (1 - 2 * x)/(2 * (-1 + x) * x);
    auto f2 = (S x) => (1 - 2 * x + 2 * x * x) / (2 * pow(1 - x, 2) * x * x);
    S[] points = [0.01, 0.99];
    test.plot("dist_arcsine", f0, f1, f2, 1.5, points);
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
