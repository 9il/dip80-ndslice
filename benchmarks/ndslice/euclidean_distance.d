#!/usr/bin/env dub
/+ dub.json:
{
    "name": "euclidean_distance",
    "dependencies": {"mir": {"path":"../.."}},
    "dflags-ldc": ["-mcpu=native"]
}
+/
/+
$ ldc2 --version
LDC - the LLVM D compiler (918073):
  based on DMD v2.071.1 and LLVM 3.8.0
  built with LDC - the LLVM D compiler (918073)
  Default target: x86_64-apple-darwin15.6.0
  Host CPU: haswell
  http://dlang.org - http://wiki.dlang.org/LDC

$ dub run --build=release-nobounds --compiler=ldmd2 --single dot_product.d

                ndReduce vectorized = 3 ms, 668 μs, and 3 hnsecs
                           ndReduce = 14 ms, 595 μs, and 3 hnsecs
  numeric.euclideanDistance, arrays = 14 ms, 463 μs, and 1 hnsec
  numeric.euclideanDistance, slices = 14 ms, 465 μs, and 5 hnsecs
                       zip & reduce = 73 ms, 678 μs, and 2 hnsecs
+/
import std.numeric : euclideanDistance;
import std.typecons;
import std.datetime;
import std.stdio;
import std.range;
import std.algorithm;
import std.conv;
import std.math : sqrt;

import mir.ndslice;
import mir.ndslice.internal : fastmath;

alias F = double;

static @fastmath F distKernel(F a, F b, F c) @safe pure nothrow @nogc
{
    auto d = b - c;
    return a + d * d;
}

// __gshared is used to prevent specialized optimization for input data
__gshared F result;
__gshared n = 8000;
__gshared F[] a;
__gshared F[] b;
__gshared Slice!(1, F*) asl;
__gshared Slice!(1, F*) bsl;

void main()
{
    a = iota(n).map!(to!F).array;
    b = a.dup;
    asl = a.sliced;
    bsl = b.sliced;

    Duration[5] bestBench = Duration.max;

    foreach(_; 0 .. 10)
    {
        auto bench = benchmark!(
            { result = ndReduce!(distKernel, Yes.vectorized)(F(0), asl, bsl).sqrt; },
            { result = ndReduce!distKernel(F(0), asl, bsl).sqrt; },
            { result = euclideanDistance(a, b); },
            { result = euclideanDistance(a.sliced, b.sliced); },
            { result = reduce!((a, b) => distKernel(a, b[0], b[1]))(0.0f, zip(a, b)).sqrt; },
        )(2000);
        foreach(i, ref b; bestBench)
            b = min(bench[i].to!Duration, b);
    }

    writefln("%35s = %s", "ndReduce vectorized", bestBench[0]);
    writefln("%35s = %s", "ndReduce", bestBench[1]);
    writefln("%35s = %s", "numeric.euclideanDistance, arrays", bestBench[2]);
    writefln("%35s = %s", "numeric.euclideanDistance, slices", bestBench[3]);
    writefln("%35s = %s", "zip & reduce", bestBench[4]);
}
