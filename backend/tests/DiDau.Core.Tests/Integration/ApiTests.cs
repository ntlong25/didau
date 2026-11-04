using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using DiDau.Core.Abstractions;
using DiDau.Core.Geo;
using DiDau.Core.Places;
using DiDau.Infrastructure.Persistence;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using NSubstitute;

namespace DiDau.Core.Tests.Integration;
public class ApiTests
{
    [Theory]
    [InlineData("osm:node/42")]
    [InlineData("goong/base64+id==")]
    public async Task SavedPlaceIdsWithSlashesRoundTrip(string id)
    {
        await using var factory = new Factory();
        factory.Places.GetDetails(id, Arg.Any<CancellationToken>()).Returns(TestData.Place(id));
        using var client = factory.CreateClient();
        var response = await client.GetAsync("/api/places/" + Uri.EscapeDataString(id));
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        await factory.Places.Received(1).GetDetails(id, Arg.Any<CancellationToken>());
    }
    [Fact]
    public async Task GeocodeFiltersToCityAndLimitsFive()
    {
        await using var factory = new Factory();
        factory.Places.TextSearch(Arg.Any<string>(), Arg.Any<GeoPoint>(), Arg.Any<CancellationToken>()).Returns([
            .. Enumerable.Range(0, 7).Select(i => TestData.Place("p" + i, 21.0288 + i * .0001)),
            TestData.Place("outside", 10.045) with { Location = new(10.045, 105.747) }]);
        using var client = factory.CreateClient();
        var response = await client.GetFromJsonAsync<JsonElement>("/api/geocode?q=Ho&cityId=hanoi");
        Assert.Equal(5, response.GetArrayLength());
        Assert.All(response.EnumerateArray(), item => Assert.Equal("hanoi", item.GetProperty("cityId").GetString()));
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/api/geocode?q=a&cityId=hanoi")).StatusCode);
    }
    [Fact]
    public async Task PlaceDetailsAreFetchedLiveOrNotFound()
    {
        await using var factory = new Factory();
        factory.Places.GetDetails("p1", Arg.Any<CancellationToken>()).Returns(TestData.Place("p1", 21.0288));
        factory.Places.GetDetails("gone", Arg.Any<CancellationToken>()).Returns((Place?)null);
        using var client = factory.CreateClient();
        var place = await client.GetFromJsonAsync<JsonElement>("/api/places/p1");
        Assert.Equal("p1", place.GetProperty("id").GetString());
        var missing = await client.GetAsync("/api/places/gone");
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        Assert.Equal("NOT_FOUND", (await missing.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
    }
    private sealed class Factory : WebApplicationFactory<Program>
    {
        public IPlacesClient Places { get; } = Substitute.For<IPlacesClient>();
        public IAttractionsClient Attractions { get; } = Substitute.For<IAttractionsClient>();
        protected override void ConfigureWebHost(IWebHostBuilder builder) => builder.ConfigureServices(services =>
        {
            var cleanup = services.FirstOrDefault(d => d.ServiceType == typeof(IHostedService) && d.ImplementationType == typeof(CacheCleanupService));
            if (cleanup is not null) services.Remove(cleanup);
            services.RemoveAll<IPlacesClient>(); services.AddSingleton(Places);
            services.RemoveAll<IAttractionsClient>(); services.AddSingleton(Attractions);
            services.RemoveAll<ICacheStore>();
            var cache = Substitute.For<ICacheStore>();
            cache.Get<string[]>(Arg.Any<string>(), Arg.Any<string>(), Arg.Any<CancellationToken>()).Returns((string[]?)null);
            services.AddSingleton(cache);
            var clock = Substitute.For<IClock>(); clock.UtcNow.Returns(TestData.Now);
            services.RemoveAll<IClock>(); services.AddSingleton(clock);
        });
    }
    [Fact]
    public async Task CitiesAndUnsupportedLocationUseContract()
    {
        await using var factory = new Factory(); using var client = factory.CreateClient();
        var cities = await client.GetFromJsonAsync<JsonElement>("/api/cities"); Assert.Equal(5, cities.GetArrayLength());
        var response = await client.PostAsJsonAsync("/api/suggestions", new { location = new { lat = 10.045, lng = 105.747 }, need = "Coffee" });
        Assert.Equal(HttpStatusCode.UnprocessableEntity, response.StatusCode);
        Assert.Equal("CITY_NOT_SUPPORTED", (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
    }
    [Theory]
    [InlineData("{}")]
    [InlineData("{\"location\":{\"lat\":21},\"need\":\"Coffee\"}")]
    [InlineData("{\"location\":{\"lat\":21,\"lng\":105.8},\"need\":\"Invalid\"}")]
    [InlineData("{\"location\":null,\"need\":\"Coffee\"}")]
    public async Task MalformedRequestsReturnVietnameseValidationError(string body)
    {
        await using var factory = new Factory(); using var client = factory.CreateClient();
        var response = await client.PostAsync("/api/suggestions", new StringContent(body, Encoding.UTF8, "application/json"));
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("VALIDATION_ERROR", (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
    }
    [Fact]
    public async Task SixthTourRequestIsRateLimited()
    {
        await using var factory = new Factory(); using var client = factory.CreateClient();
        HttpResponseMessage? response = null;
        for (var i = 0; i < 6; i++)
        {
            response?.Dispose();
            response = await client.PostAsJsonAsync("/api/tours", new { cityId = "unsupported", duration = "OneHour", interests = new[] { "History" } });
        }
        Assert.Equal(HttpStatusCode.TooManyRequests, response!.StatusCode);
        Assert.Equal("RATE_LIMITED", (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
        response.Dispose();
    }
    [Fact]
    public async Task SuggestionsSerializeLiveHoursInsidePlace()
    {
        await using var factory = new Factory();
        factory.Places.NearbySearch(Arg.Any<GeoPoint>(), Arg.Any<string[]>(), Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns([TestData.Place()]);
        using var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/suggestions", new { location = new { lat = 21.0288, lng = 105.852 }, need = "Coffee" });
        response.EnsureSuccessStatusCode();
        var place = (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("items")[0].GetProperty("place");
        Assert.True(place.GetProperty("openNow").GetBoolean());
        Assert.Equal(JsonValueKind.Null, place.GetProperty("priceLevel").ValueKind);
        Assert.True(place.GetProperty("openingHoursText").GetArrayLength() > 0);
    }
    [Fact]
    public async Task ProviderFailureDoesNotExposeDetails()
    {
        await using var factory = new Factory();
        factory.Places.NearbySearch(Arg.Any<GeoPoint>(), Arg.Any<string[]>(), Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns<Task<Place[]>>(_ => throw new HttpRequestException("sensitive-provider-detail"));
        using var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/suggestions", new { location = new { lat = 21.0288, lng = 105.852 }, need = "Coffee" });
        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
        Assert.DoesNotContain("sensitive-provider-detail", await response.Content.ReadAsStringAsync());
    }
}
