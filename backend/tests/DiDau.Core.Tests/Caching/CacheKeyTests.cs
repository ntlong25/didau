using DiDau.Core.Caching;
using DiDau.Core.Geo;

namespace DiDau.Core.Tests.Caching;

public class CacheKeyTests
{
    [Fact]
    public void NormalizesInterestsButKeepsVersionAndVariant()
    {
        var key = CacheKey.Tour("hanoi", null, "HalfDay", ["Food", "History"], 0, "v1");
        Assert.Equal(key, CacheKey.Tour("hanoi", null, "HalfDay", ["History", "Food"], 0, "v1"));
        Assert.NotEqual(key, CacheKey.Tour("hanoi", null, "HalfDay", ["History", "Food"], 1, "v1"));
        Assert.NotEqual(key, CacheKey.Tour("hanoi", null, "HalfDay", ["History", "Food"], 0, "v2"));
    }

    [Fact]
    public void NearbyPointsInsideSameCellHaveSameKey()
    {
        var a = new GeoPoint(21.0281, 105.8521);
        var b = new GeoPoint(21.0284, 105.8524);
        Assert.Equal(LocationRounding.Round(a), LocationRounding.Round(b));
        Assert.Equal(CacheKey.Nearby(a, "Coffee", 2000), CacheKey.Nearby(b, "Coffee", 2000));
    }
}
