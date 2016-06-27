module mir.random.tinflex.internal.types;

import std.traits: ReturnType, isFloatingPoint;

/**
Major data unit of the Tinflex algorithm.
It is used to store
- (cached) values of the transformation (and its derivatives)
- area below the hat and squeeze function
- linked-list like reference to the right part of the interval (there will always
be exactly one interval with right = 0)
*/
struct Interval(S)
    if (isFloatingPoint!S)
{
    import mir.random.tinflex.internal.linearfun : LinearFun;

    /// positions of the interval
    immutable S lx;
    S rx;

    /// T_c family of the interval
    immutable S c;

    /// transformed values
    immutable S ltx, lt1x, lt2x;
    S rtx, rt1x, rt2x;

    LinearFun!S hat;
    LinearFun!S squeeze;

    S hatArea;
    S squeezeArea;

    /// only supported constructor
    this (in S lx, in S rx, in S c,
          in S ltx, in S lt1x, in S lt2x,
          in S rtx, in S rt1x, in S rt2x)
    {
        this.lx = lx;
        this.rx = rx;
        this.c = c;

        this.ltx  = ltx;
        this.lt1x = lt1x;
        this.lt2x = lt2x;

        this.rtx  = rtx;
        this.rt1x = rt1x;
        this.rt2x = rt2x;
    }

    // disallow NaN points
    invariant {
        import std.math : isFinite, isNaN;
        import std.meta : AliasSeq;
        //alias seq =  AliasSeq!(x, c, tx, t1x, t2x);
        alias seq =  AliasSeq!(lx, rx, c, ltx, rtx);
        foreach (i, v; seq)
            assert(!v.isNaN, "variable " ~ seq[i].stringof ~ " isn't allowed to be NaN");

        if (lx.isFinite)
        {
            alias tseq =  AliasSeq!(lt1x, lt2x);
            foreach (i, v; tseq)
                assert(!v.isNaN, "variable " ~ tseq[i].stringof ~ " isn't allowed to be NaN");
        }
        if (rx.isFinite)
        {
            alias tseq =  AliasSeq!(rt1x, rt2x);
            foreach (i, v; tseq)
                assert(!v.isNaN, "variable " ~ tseq[i].stringof ~ " isn't allowed to be NaN");
        }
    }
}

/**
Reduced version of $(LREF Interval). Contains only the necessary information
needed in the generation phase.
*/
struct GenerationInterval(S)
    if (isFloatingPoint!S)
{
    import mir.random.tinflex.internal.linearfun : LinearFun;

    /// left position of the interval
    S lx, rx;

    /// T_c family of the interval
    S c;

    LinearFun!S hat;
    LinearFun!S squeeze;

    S hatArea;
    S squeezeArea;

    // disallow NaN points
    invariant {
        import std.math : isNaN;
        import std.meta : AliasSeq;
        alias seq =  AliasSeq!(lx, rx, c, hatArea, squeezeArea);
        foreach (i, v; seq)
            assert(!v.isNaN, "variable " ~ seq[i].stringof ~ " isn't allowed to be NaN");
    }
}

/**
Notations of different function types according to the Tinflex paper.
It is based on this naming scheme:

- a: concAve
- b: convex
- Type 4 is the pure case without any inflection point
*/
enum FunType {undefined, T1a, T1b, T2a, T2b, T3a, T3b, T4a, T4b}

/**
Determine the function type of an interval.
Based on Theorem 1 of the Tinflex paper.
Params:
    bl = left side of the interval
    br = right side of the interval
*/
FunType determineType(S)(in Interval!S iv)
in
{
    import std.math : isInfinity, isNaN;
    assert(iv.lx < iv.rx, "invalid interval");
    assert(!isNaN(iv.ltx) && !isNaN(iv.rtx), "Invalid interval points");
}
out(type)
{
    assert(type);
}
body
{
    with(FunType)
    {
        // in each unbounded interval f must be concave and strictly monotone
        if (iv.lx == -S.infinity)
        {
            if (iv.rt2x < 0 && iv.rt1x > 0)
                return T4a;
            return undefined;
        }

        if (iv.rx == +S.infinity)
        {
            if (iv.lt2x < 0 && iv.lt1x < 0)
                return T4a;
            return undefined;
        }

        if (iv.c > 0  && iv.ltx == 0 || iv.c <= 0 && iv.ltx == -S.infinity)
        {
            if (iv.rt2x < 0 && iv.rt1x > 0)
                return T4a;
            if (iv.rt2x > 0 && iv.rt1x > 0)
                return T4b;
            return undefined;
        }

        if (iv.c > 0  && iv.rtx == 0 || iv.c <= 0 && iv.rtx == -S.infinity)
        {
            if (iv.lt2x < 0 && iv.lt1x < 0)
                return T4a;
            if (iv.lt2x > 0 && iv.lt1x < 0)
                return T4b;
            return undefined;
        }

        if (iv.c < 0)
        {
            if (iv.ltx == 0  && iv.rt2x > 0 || iv.rtx == 0 && iv.lt2x > 0)
                return T4b;
        }

        // slope of the interval
        auto R = (iv.rtx - iv.ltx) / (iv.rx- iv.lx);

        if (iv.lt1x >= R && iv.rt1x >= R)
            return T1a;
        if (iv.lt1x <= R && iv.rt1x <= R)
            return T1b;

        if (iv.lt2x <= 0 && iv.rt2x <= 0)
            return T4a;
        if (iv.lt2x >= 0 && iv.rt2x >= 0)
            return T4b;

        if (iv.lt1x >= R && R >= iv.rt1x)
        {
            if (iv.lt2x < 0 && iv.rt2x > 0)
                return T2a;
            if (iv.lt2x > 0 && iv.rt2x < 0)
                return T2b;
        }
        else if (iv.lt1x <= R && R <= iv.rt1x)
        {
            if (iv.lt2x < 0 && iv.rt2x > 0)
                return T3a;
            if (iv.lt2x > 0 && iv.rt2x < 0)
                return T3b;
        }

        return undefined;
    }
}

unittest
{
    import std.meta : AliasSeq;
    foreach (S; AliasSeq!(float, double, real)) with(FunType)
    {
        const f0 = (S x) => x ^^ 4;
        const f1 = (S x) => 4 * x ^^ 3;
        const f2 = (S x) => 12 * x * x;
        enum c = 42; // c doesn't matter here
        auto dt = (S l, S r) => determineType(Interval!S(l, r, c, f0(l), f1(l), f2(l),
                                                                  f0(r), f1(r), f2(r)));

        // entirely convex
        assert(dt(-3.0, -1) == T4b);
        assert(dt(-1.0, 1) == T4b);
        assert(dt(1.0, 3) == T4b);
    }
}

// test x^3
unittest
{
    import std.meta : AliasSeq;
    foreach (S; AliasSeq!(float, double, real)) with(FunType)
    {
        const f0 = (S x) => x ^^ 3;
        const f1 = (S x) => 3 * x ^^ 2;
        const f2 = (S x) => 6 * x;
        enum c = 42; // c doesn't matter here
        auto dt = (S l, S r) => determineType(Interval!S(l, r, c, f0(l), f1(l), f2(l),
                                                                  f0(r), f1(r), f2(r)));

        // concave
        assert(dt(-S.infinity, S(-1.0)) == T4a);
        assert(dt(S(-3.0), S(-1)) == T4a);

        // inflection point at x = 0, concave before
        assert(dt(S(-1.0), S(1)) == T1a);
        // convex
        assert(dt(S(1.0), S(3)) == T4b);
    }
}

// test sin(x)
unittest
{
    import std.math: PI;
    import mir.internal.math : cos, sin;

    import std.meta : AliasSeq;
    foreach (S; AliasSeq!(float, double, real)) with(FunType)
    {
        const f0 = (S x) => sin(x);
        const f1 = (S x) => cos(x);
        const f2 = (S x) => -sin(x);
        enum c = 42; // c doesn't matter here
        auto dt = (S l, S r) => determineType(Interval!S(l, r, c, f0(l), f1(l), f2(l),
                                                                  f0(r), f1(r), f2(r)));

        // type 1a: concave
        //assert(dt(0, 2 * PI) == T1a);
        //assert(dt(2 * PI, 4 * PI) == T1a);
        //assert(dt(2, 4) == T1a);
        //assert(dt(0, 5) == T1a);
        //assert(dt(1, 5) == T1a);

        // type 1b: convex
        //assert(dt(-PI, PI) == T1b);
        //assert(dt(PI, 3 * PI) == T1b);
        //assert(dt(4, 8) == T1b);

        //// type 2a: concave
        ////assert(dt(2 * PI, 3 * PI) == T2a);
        //assert(dt(1, 4) == T2a);

        //// type 2b: convex
        //assert(dt(6, 8) == T2b);

        //// type 3a: concave
        //assert(dt(3, 4) == T3a);
        //assert(dt(2, 5.7) == T3a);

        //// type 3b: concave
        ////assert(dt(PI, 2 * PI) == T3b);
        //assert(dt(-3, 0.1) == T3b);

        // type 4a - pure concave intervals (special case of 2a)
        //assert(dt(0, PI - 0.01) == T4a);
        //assert(dt(0, 3) == T4a);

        //// type 4b - pure convex intervals (special case of 3b)
        ////assert(dt(PI, 2 * PI - 0.01) == T4b);
        //assert(dt(4, 6) == T4b);

        // TODO: zero seems to be a special case here
        //assert(dt(-PI, 0) == T4a); // should be convex!

        // but:
        //assert(dt(PI, 2 * PI) == T3b);

        //assert(dt(0, PI) == T4b); // should be concave (a)
        // but:
        //assert(dt(2 * PI, 3 * PI) == T2a);
    }
}

unittest
{
    import std.meta : AliasSeq;
    foreach (S; AliasSeq!(float, double, real)) with(FunType)
    {
        const f0 = (S x) => x * x;
        const f1 = (S x) => 2 * x;
        const f2 = (S x) => 2.0;
        enum c = 42; // c doesn't matter here
        auto dt = (S l, S r) => determineType(Interval!S(l, r, c, f0(l), f1(l), f2(l),
                                                                  f0(r), f1(r), f2(r)));
        // entirely convex
        assert(dt(-1, 1) == T4b);
        assert(dt(1, 3) == T4b);
    }
}
