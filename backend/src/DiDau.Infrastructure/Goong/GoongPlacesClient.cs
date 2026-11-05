using System.Globalization;
using System.Net;
using System.Text.Json;
using DiDau.Core.Abstractions;
using DiDau.Core.Geo;
using DiDau.Core.Places;
using Microsoft.Extensions.Configuration;

namespace DiDau.Infrastructure.Goong;

/// Goong.io REST (Google-compatible format): quick suggestions and address search.
/// Goong does not return opening hours, price or rating; those stay null ("chưa có thông tin").
/// Goong storage terms are unverified, so like before no content is kept beyond one HTTP request;
/// only place IDs are cached (nearby_cache).
public sealed class GoongPlacesClient(HttpClient http, IConfiguration config, IClock clock) : IPlacesClient
{
    private const string BaseUrl = "https://rsapi.goong.io/";
    // Each result costs one Detail call against the account quota (seen: 1000/day), so keep this small.
    private const int MaxResults = 6;
    private readonly System.Collections.Concurrent.ConcurrentDictionary<string, Lazy<Task<Place?>>> details = new();

    // Goong has no type filter, so each requested type is searched by short Vietnamese keywords.
    // Long phrases match unrelated names far away (e.g. "Thiết bị nhà hàng"), so keep them short.
    private static readonly Dictionary<string, string[]> Keywords = new()
    {
        ["cafe"] = ["cà phê"], ["coffee_shop"] = ["cà phê"], ["breakfast_restaurant"] = ["phở", "bánh mì"],
        ["brunch_restaurant"] = ["phở", "bánh mì"], ["restaurant"] = ["quán ăn", "nhà hàng"]
    };

    public async Task<Place[]> NearbySearch(GeoPoint location, string[] types, int radiusMeters, CancellationToken ct = default)
    {
        // Keywords run one after another: Goong rate-limits bursts (HTTP 429).
        var found = new List<Place>();
        foreach (var keyword in types.SelectMany(t => Keywords.GetValueOrDefault(t, [t])).Distinct())
            found.AddRange((await AutoComplete(keyword, location, radiusMeters, ct, maxDistanceMeters: radiusMeters, onlyFood: true)).Select(p => p with { Types = types }));
        return found.DistinctBy(p => p.Id).ToArray();
    }

    public Task<Place[]> TextSearch(string query, GeoPoint center, CancellationToken ct = default) =>
        AutoComplete(query, center, 10000, ct);

    public Task<Place?> GetDetails(string id, CancellationToken ct = default) =>
        details.GetOrAdd(id, key => new Lazy<Task<Place?>>(() => FetchDetails(key, ct))).Value;

    // Prediction types that mean "a place to eat or drink"; keyword matches like "Photocopy" for "phở" are dropped.
    private static readonly HashSet<string> FoodTypes = ["restaurant", "cafe", "food", "meal_delivery", "meal_takeaway", "bakery", "bar"];

    private async Task<Place[]> AutoComplete(string input, GeoPoint center, int radiusMeters, CancellationToken ct, int? maxDistanceMeters = null, bool onlyFood = false)
    {
        // Goong documents radius in kilometres.
        var radiusKm = Math.Max(1, (int)Math.Ceiling(radiusMeters / 1000.0));
        using var json = await Get("Place/AutoComplete", new()
        {
            ["input"] = input, ["location"] = Point(center), ["radius"] = radiusKm.ToString(CultureInfo.InvariantCulture),
            // origin makes Goong return distance_meters, so far results are dropped before any Detail call.
            ["origin"] = Point(center), ["limit"] = "10"
        }, ct);
        if (json is null || !json.RootElement.TryGetProperty("predictions", out var predictions)) return [];
        var ids = predictions.EnumerateArray()
            .Where(p => maxDistanceMeters is null || !p.TryGetProperty("distance_meters", out var d) || d.ValueKind != JsonValueKind.Number || d.GetDouble() <= maxDistanceMeters)
            .Where(p => !onlyFood || (p.TryGetProperty("types", out var t) && t.ValueKind == JsonValueKind.Array && t.EnumerateArray().Any(x => FoodTypes.Contains(x.GetString() ?? ""))))
            .Select(p => p.GetProperty("place_id").GetString()).OfType<string>().Distinct().Take(MaxResults);
        // Autocomplete has no coordinates; each prediction needs one Detail call (bounded concurrency).
        using var gate = new SemaphoreSlim(2);
        var places = await Task.WhenAll(ids.Select(async id =>
        {
            await gate.WaitAsync(ct);
            // One failing Detail must not fail the whole search.
            try { return await GetDetails(id, ct); }
            // Includes malformed results (missing geometry/name) that fail mapping.
            catch (Exception e) when (e is HttpRequestException or JsonException or KeyNotFoundException or InvalidOperationException) { return null; }
            finally { gate.Release(); }
        }));
        return places.OfType<Place>().ToArray();
    }

    private async Task<Place?> FetchDetails(string id, CancellationToken ct)
    {
        using var json = await Get("Place/Detail", new() { ["place_id"] = id }, ct);
        return json is not null && json.RootElement.TryGetProperty("result", out var result) ? Map(result, clock.UtcNow) : null;
    }

    private async Task<JsonDocument?> Get(string path, Dictionary<string, string> query, CancellationToken ct)
    {
        var key = config["Goong:ApiKey"];
        if (string.IsNullOrWhiteSpace(key)) throw new HttpRequestException("Goong configuration missing.");
        query["api_key"] = key;
        var url = BaseUrl + path + "?" + string.Join('&', query.Select(kv => kv.Key + "=" + Uri.EscapeDataString(kv.Value)));
        HttpResponseMessage response;
        for (var attempt = 0; ; attempt++)
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, url);
            // Goong's CDN rejects requests without a User-Agent (403, error 1010).
            request.Headers.TryAddWithoutValidation("User-Agent", config["Goong:UserAgent"] ?? "DiDau/0.1");
            response = await http.SendAsync(request, ct);
            if (response.StatusCode != HttpStatusCode.TooManyRequests || attempt >= 2) break;
            // Short backoff: Goong limits bursts per second, not just the daily quota.
            var wait = response.Headers.RetryAfter?.Delta ?? TimeSpan.FromMilliseconds(400 * (attempt + 1));
            response.Dispose();
            await Task.Delay(wait < TimeSpan.FromSeconds(2) ? wait : TimeSpan.FromSeconds(2), ct);
        }
        using var _ = response;
        if (response.StatusCode == HttpStatusCode.NotFound) return null;
        response.EnsureSuccessStatusCode();
        var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
        if (json.RootElement.TryGetProperty("status", out var status) && status.GetString() is { } s && s != "OK")
        {
            json.Dispose();
            if (s is "ZERO_RESULTS" or "NOT_FOUND" or "INVALID_REQUEST") return null;
            throw new HttpRequestException("Goong request failed.");
        }
        return json;
    }

    private static string Point(GeoPoint p) => p.Lat.ToString(CultureInfo.InvariantCulture) + "," + p.Lng.ToString(CultureInfo.InvariantCulture);

    public static Place Map(JsonElement r, DateTimeOffset now)
    {
        var id = r.GetProperty("place_id").GetString() ?? throw new JsonException("Missing place ID");
        var location = r.GetProperty("geometry").GetProperty("location");
        var name = r.TryGetProperty("name", out var n) && n.GetString() is { Length: > 0 } text ? text : id;
        var address = r.TryGetProperty("formatted_address", out var a) ? a.GetString() : null;
        var point = new GeoPoint(location.GetProperty("lat").GetDouble(), location.GetProperty("lng").GetDouble());
        // No public Goong place page exists; link to the location on Google Maps (a link, not an API call).
        var mapsUri = "https://www.google.com/maps/search/?api=1&query=" + Uri.EscapeDataString(Point(point));
        return new(id, name, point, mapsUri, now) { Address = string.IsNullOrWhiteSpace(address) ? null : address };
    }
}
