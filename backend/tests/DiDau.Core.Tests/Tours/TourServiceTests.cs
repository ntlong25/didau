using System.Text.Json;
using DiDau.Core.Abstractions;
using DiDau.Core.Caching;
using DiDau.Core.Geo;
using DiDau.Core.Tours;
using NSubstitute;

namespace DiDau.Core.Tests.Tours;
public class TourServiceTests
{
    [Fact]
    public async Task MissCachesWithoutLocationThenHitReordersWithoutLlm()
    {
        var places = Substitute.For<IPlacesClient>(); var attractions = Substitute.For<IAttractionsClient>(); var wiki = Substitute.For<IWikiClient>();
        var ai = Substitute.For<INarrationClient>(); var cache = Substitute.For<ICacheStore>(); var clock = Substitute.For<IClock>();
        clock.UtcNow.Returns(TestData.Now);
        var candidates = Enumerable.Range(0, 8).Select(i => TestData.Place("p" + i, 21.0288 + i * .0001, "historical_landmark") with { EditorialSummary = "Một địa điểm tham quan." }).ToArray();
        attractions.Search(Arg.Any<GeoPoint>(), TourService.CityRadiusMeters, Arg.Any<Interest[]>(), Arg.Any<CancellationToken>()).Returns(candidates);
        places.GetDetails(Arg.Any<string>(), Arg.Any<CancellationToken>()).Returns(call => candidates.FirstOrDefault(p => p.Id == call.Arg<string>()));
        wiki.FindByNameNear(Arg.Any<string>(), Arg.Any<GeoPoint>(), Arg.Any<CancellationToken>()).Returns(new WikiMatch("Q1", "Nguồn", null));
        wiki.GetSummary(Arg.Any<WikiMatch>(), Arg.Any<CancellationToken>()).Returns(new WikiSummary("Nguồn", "Một địa điểm tham quan.", "https://vi.wikipedia.org/wiki/Test", "vi"));
        ai.GenerateAsync(Arg.Any<string>(), Arg.Any<JsonElement>(), Arg.Any<CancellationToken>()).Returns("{\"stops\":[{\"placeId\":\"p0\",\"sections\":[{\"kind\":\"History\",\"text\":\"Xây năm 9999\",\"sourceIds\":[\"p0-description\"]}]}]}");
        CachedTour? stored = null;
        cache.Get<CachedTour>(Arg.Any<string>(), Arg.Any<string>(), Arg.Any<CancellationToken>()).Returns(_ => stored);
        cache.Set("tour_cache", Arg.Any<string>(), Arg.Any<CachedTour>(), Arg.Any<TimeSpan>(), Arg.Any<CancellationToken>()).Returns(call => { stored = call.Arg<CachedTour>(); return Task.CompletedTask; });
        var service = new TourService(places, attractions, wiki, ai, cache, clock, "v1");
        var request = new TourRequest("hanoi", TourDuration.OneHour, [Interest.History]);
        var first = await service.Get(request);
        Assert.NotNull(stored);
        var payload = JsonSerializer.Serialize(stored);
        Assert.DoesNotContain("Address", payload); Assert.DoesNotContain("OpeningHours", payload);
        Assert.DoesNotContain("Rating", payload); Assert.DoesNotContain("PriceLevel", payload);
        Assert.DoesNotContain("MapsUri", payload); Assert.DoesNotContain("UserLocation", payload);
        Assert.DoesNotContain("EditorialSummary", payload);
        Assert.DoesNotContain(first.Stops.SelectMany(s => s.Narration), n => n.Text.Contains("9999"));
        var second = await service.Get(request with { UserLocation = new(21.03, 105.852) });
        foreach (var stop in stored.Stops) await places.Received(2).GetDetails(stop.PlaceId, Arg.Any<CancellationToken>());
        Assert.Equal(first.Id, second.Id); Assert.Equal(TourStart.UserLocation, second.Start);
        Assert.Null(second.Legs[0].FromOrder); Assert.True(second.TotalMinutes <= 60);
        await ai.Received(1).GenerateAsync(Arg.Any<string>(), Arg.Any<JsonElement>(), Arg.Any<CancellationToken>());
    }
    [Fact]
    public async Task RejectsUnsupportedCity()
    {
        var service = new TourService(Substitute.For<IPlacesClient>(), Substitute.For<IAttractionsClient>(), Substitute.For<IWikiClient>(), Substitute.For<INarrationClient>(), Substitute.For<ICacheStore>(), Substitute.For<IClock>(), "v1");
        var ex = await Assert.ThrowsAsync<DomainException>(() => service.Get(new("cantho", TourDuration.OneHour, [Interest.History])));
        Assert.Equal("CITY_NOT_SUPPORTED", ex.Code);
    }
}
