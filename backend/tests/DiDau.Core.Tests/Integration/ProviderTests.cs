using System.Net;
using System.Text;
using System.Text.Json;
using DiDau.Core.Abstractions;
using DiDau.Core.Geo;
using DiDau.Core.Narration;
using DiDau.Core.Places;
using DiDau.Core.Tours;
using DiDau.Infrastructure;
using DiDau.Infrastructure.Goong;
using DiDau.Infrastructure.Osm;
using DiDau.Infrastructure.OpenAi;
using DiDau.Infrastructure.Wiki;
using Microsoft.Extensions.Configuration;
using NSubstitute;

namespace DiDau.Core.Tests.Integration;
public class ProviderTests
{
    private const string GoongDetail = "{\"status\":\"OK\",\"result\":{\"place_id\":\"g1\",\"name\":\"Cà phê Giảng\",\"formatted_address\":\"39 Nguyễn Hữu Huân\",\"geometry\":{\"location\":{\"lat\":21.0335,\"lng\":105.8546}}}}";
    [Fact]
    public async Task GoongDetailsAreCoalescedOnlyWithinOneAdapterScope()
    {
        var calls = 0;
        using var http = new HttpClient(new Handler(_ => { Interlocked.Increment(ref calls); return Task.FromResult(GoongDetail); }));
        var config = Config(new() { ["Goong:ApiKey"] = "test-token" });
        var firstRequest = new GoongPlacesClient(http, config, Substitute.For<IClock>());
        await Task.WhenAll(firstRequest.GetDetails("g1"), firstRequest.GetDetails("g1"));
        Assert.Equal(1, calls);
        await new GoongPlacesClient(http, config, Substitute.For<IClock>()).GetDetails("g1");
        Assert.Equal(2, calls);
    }
    [Fact]
    public async Task GoongNearbyUsesKeywordRadiusKmAndDoesNotInventMissingValues()
    {
        using var http = new HttpClient(new Handler(request =>
        {
            var url = Uri.UnescapeDataString(request.RequestUri!.ToString());
            Assert.Contains("api_key=test-token", url);
            if (url.Contains("Place/AutoComplete"))
            {
                Assert.Contains("input=cà phê", url); Assert.Contains("radius=3", url); Assert.Contains("location=21,105", url);
                return Task.FromResult("{\"status\":\"OK\",\"predictions\":[{\"place_id\":\"g1\"},{\"place_id\":\"g1\"}]}");
            }
            return Task.FromResult(GoongDetail);
        }));
        var client = new GoongPlacesClient(http, Config(new() { ["Goong:ApiKey"] = "test-token" }), Substitute.For<IClock>());
        var place = Assert.Single(await client.NearbySearch(new(21, 105), ["cafe", "coffee_shop"], 2160));
        Assert.Equal("Cà phê Giảng", place.Name); Assert.Equal("39 Nguyễn Hữu Huân", place.Address);
        Assert.Contains("cafe", place.Types);
        Assert.Null(place.OpeningHours); Assert.Null(place.PriceLevel); Assert.Null(place.Rating);
    }
    [Fact]
    public async Task GoongZeroResultsIsEmptyAndErrorStatusThrows()
    {
        var status = "ZERO_RESULTS";
        using var http = new HttpClient(new Handler(_ => Task.FromResult("{\"status\":\"" + status + "\"}")));
        var client = new GoongPlacesClient(http, Config(new() { ["Goong:ApiKey"] = "k" }), Substitute.For<IClock>());
        Assert.Empty(await client.TextSearch("Hồ Gươm", new(21, 105)));
        status = "REQUEST_DENIED";
        await Assert.ThrowsAsync<HttpRequestException>(() => new GoongPlacesClient(http, Config(new() { ["Goong:ApiKey"] = "k" }), Substitute.For<IClock>()).GetDetails("x"));
    }
    [Fact]
    public void OsmMapsTagsAndKeepsUnknownValuesNull()
    {
        using var json = JsonDocument.Parse("{\"type\":\"way\",\"id\":42,\"center\":{\"lat\":21.0285,\"lon\":105.8522},\"tags\":{\"name\":\"Hoan Kiem Lake\",\"name:vi\":\"Hồ Hoàn Kiếm\",\"tourism\":\"attraction\",\"historic\":\"yes\",\"wikidata\":\"Q1060569\",\"opening_hours\":\"24/7\"}}");
        var place = OverpassClient.Map(json.RootElement, TestData.Now)!;
        Assert.Equal("osm:way/42", place.Id); Assert.Equal("Hồ Hoàn Kiếm", place.Name);
        Assert.Equal("Q1060569", place.WikidataId); Assert.Equal("https://www.openstreetmap.org/way/42", place.MapsUri);
        Assert.Contains("tourist_attraction", place.Types); Assert.Contains("historical_landmark", place.Types);
        Assert.Null(place.Address); Assert.Null(place.Rating);
        Assert.Equal(new OpeningState(null, null), OpeningHours.Evaluate(place.OpeningHours, TestData.Now));
        using var unnamed = JsonDocument.Parse("{\"type\":\"node\",\"id\":1,\"lat\":21,\"lon\":105,\"tags\":{\"tourism\":\"attraction\"}}");
        Assert.Null(OverpassClient.Map(unnamed.RootElement, TestData.Now));
    }
    [Fact]
    public async Task OverpassSendsInterestFiltersAndCachesResults()
    {
        var calls = 0;
        using var http = new HttpClient(new Handler(async request =>
        {
            calls++;
            Assert.Contains("contact", string.Join(" ", request.Headers.GetValues("User-Agent")));
            var body = Uri.UnescapeDataString((await request.Content!.ReadAsStringAsync()).Replace('+', ' '));
            Assert.Contains("[\"historic\"][\"name\"](around:2500,21.0285,105.8522)", body);
            Assert.DoesNotContain("leisure", body);
            Assert.Contains("out body center", body);
            return "{\"elements\":[{\"type\":\"node\",\"id\":7,\"lat\":21.03,\"lon\":105.85,\"tags\":{\"name\":\"Đền Ngọc Sơn\",\"historic\":\"temple\"}}]}";
        }));
        var store = new Dictionary<string, object>();
        var cache = Substitute.For<ICacheStore>();
        cache.Get<Place[]>(Arg.Any<string>(), Arg.Any<string>(), Arg.Any<CancellationToken>()).Returns(call => store.GetValueOrDefault(call.ArgAt<string>(1)) as Place[]);
        cache.Set(Arg.Any<string>(), Arg.Any<string>(), Arg.Any<Place[]>(), Arg.Any<TimeSpan>(), Arg.Any<CancellationToken>())
            .Returns(call => { store[call.ArgAt<string>(1)] = call.ArgAt<Place[]>(2); return Task.CompletedTask; });
        var client = new OverpassClient(http, cache, Config(new() { ["Osm:UserAgent"] = "DiDau/1.0 (contact@example.test)" }), Substitute.For<IClock>());
        var first = await client.Search(new(21.0285, 105.8522), 2500, [Interest.History]);
        var second = await client.Search(new(21.0285, 105.8522), 2500, [Interest.History]);
        Assert.Equal("osm:node/7", Assert.Single(first).Id); Assert.Single(second);
        Assert.NotNull(await client.GetDetails("osm:node/7"));
        Assert.Equal(1, calls);
    }
    [Fact]
    public async Task DetailsAreRoutedByIdPrefix()
    {
        using var http = new HttpClient(new Handler(request => Task.FromResult(request.RequestUri!.Host.Contains("goong")
            ? GoongDetail
            : "{\"elements\":[{\"type\":\"node\",\"id\":7,\"lat\":21.03,\"lon\":105.85,\"tags\":{\"name\":\"Đền\"}}]}")));
        var cache = Substitute.For<ICacheStore>();
        cache.Get<Place[]>(Arg.Any<string>(), Arg.Any<string>(), Arg.Any<CancellationToken>()).Returns((Place[]?)null);
        var router = new RoutingPlacesClient(
            new GoongPlacesClient(http, Config(new() { ["Goong:ApiKey"] = "k" }), Substitute.For<IClock>()),
            new OverpassClient(http, cache, Config(new() { ["Osm:UserAgent"] = "ua contact" }), Substitute.For<IClock>()));
        Assert.Equal("g1", (await router.GetDetails("g1"))!.Id);
        Assert.Equal("osm:node/7", (await router.GetDetails("osm:node/7"))!.Id);
        Assert.Null(await router.GetDetails("osm:bogus"));
    }
    private sealed class Handler(Func<HttpRequestMessage, Task<string>> respond) : HttpMessageHandler
    {
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            new(HttpStatusCode.OK) { Content = new StringContent(await respond(request), Encoding.UTF8, "application/json") };
    }
    private static IConfiguration Config(Dictionary<string, string?> values) => new ConfigurationBuilder().AddInMemoryCollection(values).Build();

    [Fact]
    public async Task OverpassPartialResponseIsNotCachedAsSuccess()
    {
        using var http = new HttpClient(new Handler(_ => Task.FromResult("{\"remark\":\"runtime error: timeout\",\"elements\":[]}")));
        var cache = Substitute.For<ICacheStore>();
        cache.Get<Place[]>(Arg.Any<string>(), Arg.Any<string>(), Arg.Any<CancellationToken>()).Returns((Place[]?)null);
        var client = new OverpassClient(http, cache, Config(new() { ["Osm:UserAgent"] = "contact" }), Substitute.For<IClock>());
        await Assert.ThrowsAsync<HttpRequestException>(() => client.Search(new(21, 105), 2500, [Interest.History]));
        await cache.DidNotReceive().Set(Arg.Any<string>(), Arg.Any<string>(), Arg.Any<Place[]>(), Arg.Any<TimeSpan>(), Arg.Any<CancellationToken>());
    }

    [Theory]
    [InlineData(21.0288, true)]
    [InlineData(22.0288, false)]
    public async Task WikiRequiresNearbyCoordinates(double latitude, bool matches)
    {
        using var http = new HttpClient(new Handler(request =>
        {
            Assert.Contains("contact", string.Join(" ", request.Headers.GetValues("User-Agent")));
            var body = request.RequestUri!.Query.Contains("wbsearchentities") ? "{\"search\":[{\"id\":\"Q1\"}]}" : JsonSerializer.Serialize(new
            {
                entities = new { Q1 = new { claims = new { P625 = new[] { new { mainsnak = new { datavalue = new { value = new { latitude, longitude = 105.852 } } } } } }, sitelinks = new { viwiki = new { title = "Hồ" } } } }
            });
            return Task.FromResult(body);
        }));
        var client = new WikiClient(http, Substitute.For<ICacheStore>(), Config(new() { ["Wiki:UserAgent"] = "DiDau/1.0 (contact@example.test)" }));
        var match = await client.FindByNameNear("Hồ", new(21.0288,105.852));
        Assert.Equal(matches, match is not null);
    }
    [Fact]
    public async Task EnglishFallbackIsExplicitlyTagged()
    {
        using var http = new HttpClient(new Handler(request =>
        {
            Assert.Equal("en.wikipedia.org", request.RequestUri!.Host);
            return Task.FromResult("{\"extract\":\"A real source excerpt.\",\"type\":\"standard\"}");
        }));
        var client = new WikiClient(http, Substitute.For<ICacheStore>(), Config(new() { ["Wiki:UserAgent"] = "DiDau/1.0 (contact@example.test)" }));
        var summary = await client.GetSummary(new("Q1", null, "Lake"));
        Assert.Equal("en", summary!.Language);
        Assert.Equal("https://en.wikipedia.org/wiki/Lake", summary.Url);
    }
    [Fact]
    public async Task NarrationUsesConfiguredModelStrictSchemaAndNoStorage()
    {
        using var http = new HttpClient(new Handler(async request =>
        {
            Assert.Equal("Bearer", request.Headers.Authorization!.Scheme);
            using var body = JsonDocument.Parse(await request.Content!.ReadAsStringAsync());
            Assert.Equal("configured-model", body.RootElement.GetProperty("model").GetString());
            Assert.False(body.RootElement.GetProperty("store").GetBoolean());
            Assert.True(body.RootElement.GetProperty("response_format").GetProperty("json_schema").GetProperty("strict").GetBoolean());
            return "{\"choices\":[{\"finish_reason\":\"stop\",\"message\":{\"content\":\"{\\\"stops\\\":[]}\"}}]}";
        }));
        var client = new OpenAiNarrationClient(http, Config(new() { ["OpenAi:ApiKey"] = "test-token", ["OpenAi:Model"] = "configured-model" }));
        Assert.Equal("{\"stops\":[]}", await client.GenerateAsync("source facts", PromptBuilder.Schema));
    }
}
