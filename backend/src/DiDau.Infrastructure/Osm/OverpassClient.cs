using System.Globalization;
using System.Text.Json;
using DiDau.Core.Abstractions;
using DiDau.Core.Caching;
using DiDau.Core.Geo;
using DiDau.Core.Places;
using DiDau.Core.Tours;
using Microsoft.Extensions.Configuration;

namespace DiDau.Infrastructure.Osm;

/// OpenStreetMap attractions via the Overpass API. Data is ODbL, so results may be stored;
/// they are cached in osm_cache to respect the public Overpass usage policy.
public sealed class OverpassClient(HttpClient http, ICacheStore cache, IConfiguration config, IClock clock) : IAttractionsClient
{
    public const string IdPrefix = "osm:";
    private static readonly TimeSpan SearchTtl = TimeSpan.FromHours(24);
    private readonly System.Collections.Concurrent.ConcurrentDictionary<string, Place> searchPlaces = new();

    public Task<Place[]> Search(GeoPoint center, int radiusMeters, Interest[] interests, CancellationToken ct = default)
    {
        var filters = interests.Distinct().Order().SelectMany(i => i switch
        {
            Interest.History => new[] { "[\"historic\"][\"name\"]", "[\"tourism\"=\"museum\"][\"name\"]", "[\"amenity\"=\"place_of_worship\"][\"name\"][\"wikidata\"]" },
            Interest.Food => ["[\"amenity\"~\"^(restaurant|cafe|marketplace)$\"][\"name\"]"],
            _ => ["[\"tourism\"~\"^(attraction|viewpoint|artwork|gallery)$\"][\"name\"]", "[\"leisure\"=\"park\"][\"name\"]"]
        });
        return Query(Around(filters, center, radiusMeters), ct);
    }

    public Task<Place[]> Famous(GeoPoint center, int radiusMeters, CancellationToken ct = default) =>
        Query(Around(["[\"tourism\"~\"^(attraction|museum)$\"][\"name\"][\"wikidata\"]", "[\"historic\"][\"name\"][\"wikidata\"]"], center, radiusMeters), ct);

    public async Task<Place?> GetDetails(string id, CancellationToken ct = default)
    {
        if (!id.StartsWith(IdPrefix, StringComparison.Ordinal)) return null;
        var parts = id[IdPrefix.Length..].Split('/');
        if (parts is not [("node" or "way" or "relation") and var type, var number] || !long.TryParse(number, NumberStyles.None, CultureInfo.InvariantCulture, out var numericId) || numericId <= 0) return null;
        var key = "place:" + id;
        if (searchPlaces.TryGetValue(id, out var searched))
        {
            await cache.Set("osm_cache", key, new[] { searched }, SearchTtl, ct);
            return searched;
        }
        var cached = await cache.Get<Place[]>("osm_cache", key, ct);
        if (cached is not null) return cached.FirstOrDefault();
        var found = await Fetch($"{type}({number});", ct);
        await cache.Set("osm_cache", key, found, CacheTtl.Place, ct);
        return found.FirstOrDefault();
    }

    public static string Around(IEnumerable<string> filters, GeoPoint center, int radiusMeters)
    {
        var around = string.Create(CultureInfo.InvariantCulture, $"(around:{radiusMeters},{center.Lat},{center.Lng})");
        return string.Concat(filters.Select(f => "nwr" + f + around + ";"));
    }

    private async Task<Place[]> Query(string statements, CancellationToken ct)
    {
        var key = "search-v2:" + CacheKey.Hash(statements);
        var cached = await cache.Get<Place[]>("osm_cache", key, ct);
        var places = cached ?? await Fetch(statements, ct);
        if (cached is null) await cache.Set("osm_cache", key, places, SearchTtl, ct);
        foreach (var place in places) searchPlaces[place.Id] = place;
        return places;
    }

    private async Task<Place[]> Fetch(string statements, CancellationToken ct)
    {
        var userAgent = config["Osm:UserAgent"] ?? config["Wiki:UserAgent"];
        if (string.IsNullOrWhiteSpace(userAgent)) throw new HttpRequestException("OSM contact User-Agent is not configured.");
        var body = $"[out:json][timeout:20];({statements});out body center 150;";
        // Public Overpass servers are often at capacity (502/504): fail fast and try the next mirror.
        string? text = null;
        HttpRequestException? last = null;
        foreach (var url in Endpoints(config))
        {
            using var attempt = CancellationTokenSource.CreateLinkedTokenSource(ct);
            attempt.CancelAfter(AttemptTimeout);
            try
            {
                using var request = new HttpRequestMessage(HttpMethod.Post, url) { Content = new FormUrlEncodedContent([new("data", body)]) };
                request.Headers.TryAddWithoutValidation("User-Agent", userAgent);
                using var response = await http.SendAsync(request, attempt.Token);
                response.EnsureSuccessStatusCode();
                text = await response.Content.ReadAsStringAsync(attempt.Token);
                break;
            }
            catch (HttpRequestException e) { last = e; }
            catch (OperationCanceledException) when (!ct.IsCancellationRequested) { last = new HttpRequestException("Overpass mirror timed out."); }
        }
        if (text is null) throw last ?? new HttpRequestException("No Overpass endpoint configured.");
        using var json = JsonDocument.Parse(text);
        if (json.RootElement.TryGetProperty("remark", out _))
            throw new HttpRequestException("Overpass returned an incomplete response.");
        var now = clock.UtcNow;
        return json.RootElement.GetProperty("elements").EnumerateArray().Select(e => Map(e, now)).OfType<Place>().DistinctBy(p => p.Id).ToArray();
    }

    private static readonly TimeSpan AttemptTimeout = TimeSpan.FromSeconds(12);
    private static readonly string[] DefaultEndpoints =
    [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.private.coffee/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    ];
    // Osm:OverpassUrls (array) or Osm:OverpassUrl (single) override the public mirrors, e.g. a self-hosted instance.
    private static string[] Endpoints(IConfiguration config)
    {
        var list = config.GetSection("Osm:OverpassUrls").GetChildren().Select(c => c.Value).OfType<string>().ToArray();
        if (list.Length > 0) return list;
        return config["Osm:OverpassUrl"] is { Length: > 0 } single ? [single] : DefaultEndpoints;
    }

    public static Place? Map(JsonElement e, DateTimeOffset now)
    {
        if (!e.TryGetProperty("tags", out var tags)) return null;
        string? Tag(string name) => tags.TryGetProperty(name, out var v) && v.GetString() is { Length: > 0 } s ? s : null;
        var name = Tag("name:vi") ?? Tag("name");
        var point = e.TryGetProperty("center", out var c) ? c : e;
        if (name is null || !point.TryGetProperty("lat", out var lat) || !point.TryGetProperty("lon", out var lon)) return null;
        var type = e.GetProperty("type").GetString()!;
        var osmId = e.GetProperty("id").GetInt64().ToString(CultureInfo.InvariantCulture);
        var street = string.Join(' ', new[] { Tag("addr:housenumber"), Tag("addr:street") }.OfType<string>());
        var address = Tag("addr:full") ?? string.Join(", ", new[] { street, Tag("addr:subdistrict"), Tag("addr:district"), Tag("addr:city") }
            .Where(s => !string.IsNullOrWhiteSpace(s)));
        var hours = Tag("opening_hours");
        return new(IdPrefix + type + "/" + osmId, name, new(lat.GetDouble(), lon.GetDouble()), $"https://www.openstreetmap.org/{type}/{osmId}", now)
        {
            Address = string.IsNullOrWhiteSpace(address) ? null : address,
            // OSM opening_hours syntax is not parsed; the raw text is shown and open/closed stays unknown.
            OpeningHours = hours is null ? null : new([], [hours]),
            Types = Types(Tag("tourism"), Tag("historic"), Tag("amenity"), Tag("leisure"), Tag("natural")),
            WikidataId = Tag("wikidata")
        };
    }

    // Maps OSM tags onto the type names RouteBuilder scores against.
    private static string[] Types(string? tourism, string? historic, string? amenity, string? leisure, string? natural) => new[]
    {
        tourism switch { "museum" => "museum", "attraction" or "viewpoint" or "artwork" or "gallery" => "tourist_attraction", _ => null },
        historic is null ? null : "historical_landmark",
        amenity switch { "place_of_worship" => "place_of_worship", "restaurant" => "restaurant", "cafe" => "cafe", "marketplace" => "market", _ => null },
        leisure == "park" ? "park" : null,
        natural is null ? null : "natural_feature"
    }.OfType<string>().ToArray();
}
