using System.Net;
using System.Text;
using System.Text.Json;
using DiDau.Core.Abstractions;
using DiDau.Core.Geo;
using DiDau.Core.Narration;
using DiDau.Infrastructure.GooglePlaces;
using DiDau.Infrastructure.OpenAi;
using DiDau.Infrastructure.Wiki;
using Microsoft.Extensions.Configuration;
using NSubstitute;

namespace DiDau.Core.Tests.Integration;
public class ProviderTests
{
    [Fact]
    public async Task PlaceDetailsAreCoalescedOnlyWithinOneAdapterScope()
    {
        var calls = 0;
        using var http = new HttpClient(new Handler(_ =>
        {
            Interlocked.Increment(ref calls);
            return Task.FromResult("{\"id\":\"p1\",\"displayName\":{\"text\":\"Place\"},\"location\":{\"latitude\":21,\"longitude\":105}}");
        }));
        var config = Config(new() { ["GooglePlaces:ApiKey"] = "test-token" });
        var firstRequest = new GooglePlacesClient(http, config, Substitute.For<IClock>());
        await Task.WhenAll(firstRequest.GetDetails("p1"), firstRequest.GetDetails("p1"));
        Assert.Equal(1, calls);
        var nextRequest = new GooglePlacesClient(http, config, Substitute.For<IClock>());
        await nextRequest.GetDetails("p1");
        Assert.Equal(2, calls);
    }
    private sealed class Handler(Func<HttpRequestMessage, Task<string>> respond) : HttpMessageHandler
    {
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            new(HttpStatusCode.OK) { Content = new StringContent(await respond(request), Encoding.UTF8, "application/json") };
    }
    private static IConfiguration Config(Dictionary<string, string?> values) => new ConfigurationBuilder().AddInMemoryCollection(values).Build();

    [Fact]
    public async Task PlacesSendsNewApiMaskAndVietnameseLanguage()
    {
        using var http = new HttpClient(new Handler(async request =>
        {
            Assert.Equal("https://places.googleapis.com/v1/places:searchNearby", request.RequestUri!.ToString());
            Assert.Equal("test-token", request.Headers.GetValues("X-Goog-Api-Key").Single());
            Assert.Contains("places.regularOpeningHours", request.Headers.GetValues("X-Goog-FieldMask").Single());
            using var body = JsonDocument.Parse(await request.Content!.ReadAsStringAsync());
            Assert.Equal("vi", body.RootElement.GetProperty("languageCode").GetString());
            return "{\"places\":[]}";
        }));
        var client = new GooglePlacesClient(http, Config(new() { ["GooglePlaces:ApiKey"] = "test-token" }), Substitute.For<IClock>());
        Assert.Empty(await client.NearbySearch(new(21,105), ["cafe"], 2000));
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
