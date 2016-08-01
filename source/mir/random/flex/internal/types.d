module mir.random.flex.internal.types;

import std.traits: ReturnType, isFloatingPoint;

/**
Major data unit of the Flex algorithm.
It is used to store
- (cached) values of the transformation (and its derivatives)
- area below the hat and squeeze function
- linked-list like reference to the right part of the interval (there will always
be exactly one interval with right = 0)
*/
struct Interval(S)
    if (isFloatingPoint!S)
{
    import mir.utility.linearfun : LinearFun;

    /// left position of the interval
    S lx;

    /// right position of the interval
    S rx;

    /// T_c family of the interval
    S c;

    /// transformed left value of lx
    S ltx;

    /// transformed value of the first derivate of the left lx value
    S lt1x;

    /// transformed value of the second derivate of the left lx value
    S lt2x;

    /// transformed right value of rx
    S rtx;

    /// transformed value of the first derivate of the right rx value
    S rt1x;

    /// transformed value of the second derivate of the right rx value
    S rt2x;

    /// hat function of the interval
    LinearFun!S hat;

    /// squeeze function of the interval
    LinearFun!S squeeze;

    /// calculated area of the integrated hat function
    S hatArea;

    /// calculated area of the integrated squeeze function
    S squeezeArea;

    // workaround against @@@BUG 16331@@@
    // sets NaN's to be equal on comparison
    version(Flex_logging)
    bool opEquals(const Interval s2) const
    {
        import std.math : isNaN, isFloatingPoint;
        import std.meta : AliasSeq;
        string buildMixin()
        {
            enum symbols = AliasSeq!("lx", "rx", "c", "ltx", "lt1x", "lt2x",
                                     "rtx", "rt1x", "rt2x", "hat", "squeeze", "hatArea", "squeezeArea");
            enum linSymbols = AliasSeq!("slope", "y", "a");
            string s = "return ";
            foreach (i, attr; symbols)
            {
                if (i > 0)
                    s ~= " && ";
                s ~= "(";
                auto attrName = symbols[i].stringof;
                alias T = typeof(mixin("typeof(this).init." ~ attr));

                if (isFloatingPoint!T)
                {
                    // allow NaNs
                    s ~= "this." ~ attr ~ ".isNaN && s2." ~ attr ~ ".isNaN ||";
                }
                else if (is(T == const LinearFun!S))
                {
                    // allow NaNs
                    s ~= "(";
                    foreach (j, linSymbol; linSymbols)
                    {
                        if (j > 0)
                            s ~= "||";
                        s ~= attr ~ "." ~ linSymbol ~ ".isNaN";
                        s ~= "&& s2." ~ attr ~ "." ~ linSymbol ~ ".isNaN";
                    }
                    s ~= ") ||";
                }
                s ~= attr ~ " == s2." ~ attr;
                s ~= ")";
            }
            s ~= ";";
            return s;
        }
        mixin(buildMixin());
    }

    ///
    version(Flex_logging_hex) string logHex()
    {
        import std.format : format;
        return "Interval!%s(%a, %a, %a, %a, %a, %a, %a, %a, %a, %s, %s, %a, %a)"
               .format(S.stringof, lx, rx, c, ltx, lt1x, lt2x, rtx, rt1x, rt2x,
                       hat.logHex, squeeze.logHex, hatArea, squeezeArea);
    }
}

/**
Notations of different function types according to Botts et al. (2013).
It is based on this naming scheme:

- a: concAve
- b: convex
- Type 4 is the pure case without any inflection point
*/
enum FunType {undefined, T1a, T1b, T2a, T2b, T3a, T3b, T4a, T4b}

/**
Determine the function type of an interval.
Based on Theorem 1 of the Flex paper.
Params:
    bl = left side of the interval
    br = right side of the interval
*/
FunType determineType(S)(in Interval!S iv)
in
{
    import std.math : isInfinity, isNaN;
    assert(iv.lx < iv.rx, "invalid interval");
}
out(type)
{
    import std.conv : to;
    assert(type, iv.to!string);
}
body
{
    with(FunType)
    {
        // In each unbounded interval f must be concave and strictly monotone
        // Condition 4 in section 2.3 from Botts et al. (2013)
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
