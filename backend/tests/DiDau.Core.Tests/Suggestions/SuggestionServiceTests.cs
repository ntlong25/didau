using DiDau.Core.Abstractions;
using DiDau.Core.Caching;
using DiDau.Core.Geo;
using DiDau.Core.Places;
using DiDau.Core.Suggestions;
using NSubstitute;

namespace DiDau.Core.Tests.Suggestions;

public class SuggestionServiceTests
{
    [Fact]
    public async Task CachedSearchRetainsQueryMatchWhenDetailsHaveNoCategory()
    {
        var service = Service();
        var point = new GeoPoint(21.0288, 105.852);
        places.NearbySearch(Arg.Any<GeoPoint>(), Arg.Any<string[]>(), Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns([TestData.Place()]);
        places.GetDetails("p1", Arg.Any<CancellationToken>()).Returns(TestData.Place() with { Types = [] });
        var first = await service.Get(new(point, Need.Coffee));
        var call = cache.ReceivedCalls().Single(c => c.GetMethodInfo().Name == "Set");
        var key = (string)call.GetArguments()[1]!;
        var ids = (string[])call.GetArguments()[2]!;
        cache.Get<string[]>("nearby_cache", key, Arg.Any<CancellationToken>()).Returns(ids);
        var second = await service.Get(new(point, Need.Coffee));
        Assert.Single(first.Items);
        Assert.Single(second.Items);
        await places.Received(1).NearbySearch(Arg.Any<GeoPoint>(), Arg.Any<string[]>(), Arg.Any<int>(), Arg.Any<CancellationToken>());
    }
    private readonly IPlacesClient places = Substitute.For<IPlacesClient>();
    private readonly ICacheStore cache = Substitute.For<ICacheStore>();
    private readonly IClock clock = Substitute.For<IClock>();
    private SuggestionService Service()
    {
        clock.UtcNow.Returns(TestData.Now);
        cache.Get<string[]>(Arg.Any<string>(), Arg.Any<string>(), Arg.Any<CancellationToken>()).Returns((string[]?)null);
        return new(places, cache, clock);
    }
    [Fact]
    public async Task RejectsUnsupportedCityBeforeCallingProvider()
    {
        var error = await Assert.ThrowsAsync<DomainException>(() => Service().Get(new(new(10.045, 105.747), Need.Coffee)));
        Assert.Equal("CITY_NOT_SUPPORTED", error.Code);
        Assert.Empty(places.ReceivedCalls());
    }
    [Fact]
    public async Task FiltersClosedRanksOpenAndLimitsFive()
    {
        var candidates = Enumerable.Range(0, 8).Select(i => TestData.Place($"p{i}", 21.0288 + i * .0001)).ToArray();
        candidates[0] = candidates[0] with { BusinessStatus = BusinessStatus.ClosedPermanently };
        candidates[1] = candidates[1] with { OpeningHours = new([new(2, 0, 2, 60)], []) };
        places.NearbySearch(Arg.Any<GeoPoint>(), Arg.Any<string[]>(), Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns(candidates);
        var result = await Service().Get(new(new(21.0288, 105.852), Need.Coffee));
        Assert.Equal(5, result.Items.Length);
        Assert.DoesNotContain(result.Items, i => i.Place.Id is "p0" or "p1");
        Assert.Equal("p2", result.Items[0].Place.Id);
        Assert.False(result.CanExpandRadius);
    }
    [Theory]
    [InlineData(2000, true)]
    [InlineData(5000, false)]
    public async Task ExpansionAndRoundedCache(int radius, bool expand)
    {
        places.NearbySearch(Arg.Any<GeoPoint>(), Arg.Any<string[]>(), Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns([TestData.Place()]);
        var point = new GeoPoint(21.0288, 105.852);
        var result = await Service().Get(new(point, Need.Coffee, radius));
        Assert.Equal(expand, result.CanExpandRadius);
        await places.Received().NearbySearch(LocationRounding.Round(point), Arg.Any<string[]>(), Arg.Any<int>(), Arg.Any<CancellationToken>());
        await cache.Received().Set("nearby_cache", "goong-v2:" + CacheKey.Nearby(point, "Coffee", radius), Arg.Any<string[]>(), CacheTtl.Nearby, Arg.Any<CancellationToken>());
    }
    [Fact]
    public async Task BreakfastAtNightRequiresBreakfastEvidenceAndNextOpening()
    {
        var service = Service();
        clock.UtcNow.Returns(DateTimeOffset.Parse("2026-11-03T21:00:00+07:00"));
        places.NearbySearch(Arg.Any<GeoPoint>(), Arg.Any<string[]>(), Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns([
            TestData.Place("breakfast", type: "breakfast_restaurant") with { OpeningHours = new([new(3, 360, 3, 660)], []) },
            TestData.Place("generic-cafe")]);
        var result = await service.Get(new(new(21.0288, 105.852), Need.Breakfast));
        Assert.Single(result.Items);
        Assert.NotNull(result.Items[0].NextOpenAt);
    }
}
