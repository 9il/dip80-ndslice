#!/usr/bin/env dub
/+ dub.sdl:
name "flex_plot1"
dependency "flex_common" path="./common"
versions "Flex_logging" "Flex_single"
+/

/// Default flex testing distribution
void test(S, F)(in ref F test)
{
    import std.math : pow;
    import std.conv : to;

    auto f0 = (S x) => -pow(x, 4) + 5 * x * x - 4;
    auto f1 = (S x) => 10 * x - 4 * pow(x, 3);
    auto f2 = (S x) => 10 - 12 * x * x;

    foreach (c; [0.1, 0.5, 1])
    {
        test.plot("dist1_a" ~ c.to!string, f0, f1, f2, c, [-3.0, -1.5, 0.0, 1.5, 3]);
    }

    foreach (c; [-0.9, -0.5, -0.2, 0])
    {
        test.plot("dist1_b" ~ c.to!string, f0, f1, f2, c,
            [-S.infinity, -2.1, -1.05, 0.1, 1.2, 2, S.infinity]);
        test.plot("dist1_c" ~ c.to!string, f0, f1, f2, c, [-S.infinity, -1, 0, 1, S.infinity]);
        test.plot("dist1_d" ~ c.to!string, f0, f1, f2, c, [-2, 0, 1.5], -4, 6);
    }

    foreach (c; [-2, -1.5, -1])
    {
        test.plot("dist1_e" ~ c.to!string, f0, f1, f2, c, [-3.0, -2.1, -1.05, 0.1, 1.2, 3]);
    }
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
