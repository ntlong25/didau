using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using DiDau.Core.Abstractions;
using DiDau.Core.Caching;
using DiDau.Core.Geo;
using DiDau.Core.Places;
using Microsoft.Extensions.Configuration;

namespace DiDau.Infrastructure.GooglePlaces;

public sealed class GooglePlacesClient(HttpClient http, IConfiguration config, IClock clock) : IPlacesClient
{
    // This adapter is scoped to one HTTP request; no Places content survives that scope.
    private readonly System.Collections.Concurrent.ConcurrentDictionary<string, Lazy<Task<Place?>>> details = new();
    private const string Fields = "id,displayName,formattedAddress,location,types,regularOpeningHours,priceLevel,rating,userRatingCount,businessStatus,editorialSummary,googleMapsUri";

    public Task<Place[]> NearbySearch(GeoPoint location, string[] types, int radiusMeters, CancellationToken ct = default) =>
        Search("places:searchNearby", new { includedTypes = types, maxResultCount = 20, languageCode = "vi",
            locationRestriction = new { circle = new { center = new { latitude = location.Lat, longitude = location.Lng }, radius = radiusMeters } } }, ct);

    public Task<Place[]> TextSearch(string query, GeoPoint center, CancellationToken ct = default) =>
        Search("places:searchText", new { textQuery = query, languageCode = "vi", pageSize = 20,
            locationBias = new { circle = new { center = new { latitude = center.Lat, longitude = center.Lng }, radius = 10000 } } }, ct);

    public Task<Place?> GetDetails(string id, CancellationToken ct = default) =>
        details.GetOrAdd(id, key => new Lazy<Task<Place?>>(() => FetchDetails(key, ct))).Value;

    private async Task<Place?> FetchDetails(string id, CancellationToken ct)
    {
        using var request = Request(HttpMethod.Get, $"places/{Uri.EscapeDataString(id)}?languageCode=vi", false);
        using var response = await http.SendAsync(request, ct);
        if (response.StatusCode == HttpStatusCode.NotFound) return null;
        response.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
        var place = Map(json.RootElement, clock.UtcNow);
        return place;
    }

    private async Task<Place[]> Search(string path, object body, CancellationToken ct)
    {
        using var request = Request(HttpMethod.Post, path, true);
        request.Content = JsonContent.Create(body);
        using var response = await http.SendAsync(request, ct);
        response.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
        if (!json.RootElement.TryGetProperty("places", out var items)) return [];
        var places = items.EnumerateArray().Select(p => Map(p, clock.UtcNow)).ToArray();
        foreach (var place in places) details.TryAdd(place.Id, new Lazy<Task<Place?>>(() => Task.FromResult<Place?>(place)));
        return places;
    }

    private HttpRequestMessage Request(HttpMethod method, string path, bool list)
    {
        var key = config["GooglePlaces:ApiKey"];
        if (string.IsNullOrWhiteSpace(key)) throw new HttpRequestException("Places configuration missing.");
        var request = new HttpRequestMessage(method, "https://places.googleapis.com/v1/" + path);
        request.Headers.Add("X-Goog-Api-Key", key);
        request.Headers.Add("X-Goog-FieldMask", list ? string.Join(',', Fields.Split(',').Select(f => "places." + f)) : Fields);
        return request;
    }

    public static Place Map(JsonElement p, DateTimeOffset now)
    {
        static string? Text(JsonElement e, string name) => e.TryGetProperty(name, out var v) ? v.GetString() : null;
        static int Minute(JsonElement e) => (e.TryGetProperty("hour", out var h) ? h.GetInt32() : 0) * 60 + (e.TryGetProperty("minute", out var m) ? m.GetInt32() : 0);
        var id = p.GetProperty("id").GetString() ?? throw new JsonException("Missing place ID");
        var location = p.GetProperty("location");
        WeeklyHours? hours = null;
        if (p.TryGetProperty("regularOpeningHours", out var opening) && opening.TryGetProperty("periods", out var periods))
            hours = new(periods.EnumerateArray().Select(period =>
            {
                var open = period.GetProperty("open");
                var hasClose = period.TryGetProperty("close", out var close);
                return new WeeklyPeriod(open.GetProperty("day").GetInt32(), Minute(open), hasClose ? close.GetProperty("day").GetInt32() : null, hasClose ? Minute(close) : 0);
            }).ToArray(), opening.TryGetProperty("weekdayDescriptions", out var days) ? days.EnumerateArray().Select(d => d.GetString()!).ToArray() : []);
        return new(id, p.GetProperty("displayName").GetProperty("text").GetString()!,
            new(location.GetProperty("latitude").GetDouble(), location.GetProperty("longitude").GetDouble()),
            Text(p, "googleMapsUri") ?? $"https://www.google.com/maps/search/?api=1&query=place&query_place_id={Uri.EscapeDataString(id)}", now)
        {
            Address = Text(p, "formattedAddress"), OpeningHours = hours,
            Types = p.TryGetProperty("types", out var types) ? types.EnumerateArray().Select(t => t.GetString()!).ToArray() : [],
            PriceLevel = Text(p, "priceLevel") switch { "PRICE_LEVEL_INEXPENSIVE" => PriceLevel.Inexpensive, "PRICE_LEVEL_MODERATE" => PriceLevel.Moderate, "PRICE_LEVEL_EXPENSIVE" => PriceLevel.Expensive, "PRICE_LEVEL_VERY_EXPENSIVE" => PriceLevel.VeryExpensive, _ => null },
            BusinessStatus = Text(p, "businessStatus") switch { "CLOSED_PERMANENTLY" => BusinessStatus.ClosedPermanently, "CLOSED_TEMPORARILY" => BusinessStatus.ClosedTemporarily, _ => BusinessStatus.Operational },
            Rating = p.TryGetProperty("rating", out var rating) ? rating.GetDecimal() : null,
            UserRatingCount = p.TryGetProperty("userRatingCount", out var count) ? count.GetInt32() : null,
            EditorialSummary = p.TryGetProperty("editorialSummary", out var summary) ? Text(summary, "text") : null
        };
    }
}
