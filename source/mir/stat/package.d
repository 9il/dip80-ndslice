/**
Statistical functions

License: $(LINK2 http://boost.org/LICENSE_1_0.txt, Boost License 1.0).
*/

module mir.stat;

import std.range: isInputRange, isInfinite;
import std.range;

/**
Cumulative computation of mean and variance of an observed distribution.

Params:
    rs = InputRange of observed elements

Returns:
    $(LREF StatReport) with the observed mean and variance
*/
StatReport!R stat(R)(R rs)
if (isInputRange!R && !isInfinite!R)
{
    return StatReport!R(rs);
}

/**
$(WEB https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Online_algorithm, Online)
statistical report about mean and variance as an OutputRange.
It computes the mean and variance.

See_Also:
    $(LREF stat)
*/
struct StatReport(R)
if (isInputRange!R && !isInfinite!R)
{
import std.range: ElementType;

alias E = ElementType!R;
alias FType = double;

private:
    ulong _nrs = 0;
    FType _mean = 0;
    FType _m2 = 0;

public:

    ///
    this(ref R rs)
    {
        put(rs);
    }

    /// Knuth & Welford online-update
    void put(FType x)
    {
        const auto delta = (x - _mean);
        this._mean += delta / ++_nrs;
        this._m2 += delta * (x - mean);
    }

    /// Knuth & Welford online-update
    void put(T)(auto ref T rs)
    if (isInputRange!T && !isInfinite!T)
    {
        foreach (r; rs)
        {
            put(r);
        }
    }

    /** Online combine after
    $(WEB http://i.stanford.edu/pub/cstr/reports/cs/tr/79/773/CS-TR-79-773.pdf, Chain et. al)
    **/
    void put(A)(auto ref A rs)
    if (is(typeof(A.mean + A.nrs + A._m2)))
    {
        import std.math: pow;
        const auto rsnrs = rs.nrs;
        const auto nx = _nrs + rsnrs;
        const auto delta = rs.mean - _mean;
        _mean += delta * rsnrs / nx;
        _m2 = _m2 + rs._m2 + pow(delta, 2) * _nrs * rsnrs  / nx;
        _nrs = nx;
    }

    ///
    typeof(this) save()
    {
        return this;
    }

    /// Mean
    auto mean()
    {
        return _mean;
    }

    /// Variance
    auto var()
    {
        return (_nrs < 2) ? double.nan : _m2 / (_nrs - 1);
    }

    /// Sum of all observed elements
    auto sum()
    {
        return _nrs * _mean;
    }

    /// Standard deviation
    auto stddev()
    {
        import std.math: sqrt;
        return sqrt(this.var);
    }

    /// Number of observed elements
    auto nrs()
    {
        return _nrs;
    }
}

///
@safe pure nothrow @nogc unittest
{
    import std.range: iota;
    import std.math: approxEqual;

    assert(iota(11).stat.mean.approxEqual(5.0));
    assert(iota(-10, 0).stat.mean.approxEqual(-5.5));

    assert(iota(9).stat.var.approxEqual(7.5));
    assert(iota(-10, 0).stat.var.approxEqual(9.1667));

    assert(iota(11).stat.stddev.approxEqual(3.3166));
    assert(iota(-10, 0).stat.stddev.approxEqual(3.02765));

    assert(iota(10).stat.sum == 45);
}

@safe pure nothrow @nogc unittest
{
    import std.range: iota;
    import std.math: approxEqual;

    auto s1 = iota(4).stat;
    assert(s1.nrs == 4);

    s1.put(iota(4, 10).stat);
    assert(s1.mean.approxEqual(4.5));
    assert(s1.var.approxEqual(9.1667));

    import std.range: isOutputRange;
    static assert(isOutputRange!(typeof(s1), double));

    auto s2 = iota(-10, -7).stat;
    assert(s2.nrs == 3);

    s2.put(iota(-7, 0).stat);
    assert(s2.mean.approxEqual(-5.5));
    assert(s1.var.approxEqual(9.1667));
    assert(s2.nrs == 10);
}

// online update with high precision
@safe pure nothrow @nogc unittest
{
    import std.range: iota, takeExactly, dropExactly;
    import std.math: approxEqual;
    import std.algorithm: map;

    static immutable h = 1e14;

    static immutable arr = [h + 4, h + 7, h + 13, h + 16];
    assert(arr.stat.var.approxEqual(30, 0.0001));

    auto arr2 = iota(10).map!(a => h + a);
    auto s1 = arr2.takeExactly(4).stat;
    assert(s1.nrs == 4);
    assert(s1.var.approxEqual(1.6667, 0.01));

    s1.put(arr2.dropExactly(4).stat);
    assert(s1.var.approxEqual(9.1667));
    assert(s1.nrs == 10);
}

// check "save"
@safe pure nothrow @nogc unittest
{
    import std.range: iota;
    import std.math: approxEqual;

    auto s1 = iota(4).stat;
    assert(s1.nrs == 4);
    auto s1c = s1.save;
    s1c.put(4);
    s1c.put(iota(5, 9));
    s1c.put(iota(9, 20).stat);

    assert(s1.nrs == 4);
    assert(s1c.nrs == 20);
    assert(s1c.sum == 190);
    assert(s1c.mean.approxEqual(9.5));
    assert(s1c.var.approxEqual(35));
}
