using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using DiDau.Core.Geo;

namespace DiDau.Core.Caching;

public static class LocationRounding
{
    public static GeoPoint Round(GeoPoint p) => new(Math.Round(p.Lat / .002, MidpointRounding.AwayFromZero) * .002,
        Math.Round(p.Lng / .002, MidpointRounding.AwayFromZero) * .002);
}
public static class CacheKey
{
    public static string Hash(object value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(value)))).ToLowerInvariant();
    public static string Tour(string city, string? area, string duration, IEnumerable<string> interests, int variant, string version) =>
        Hash(new { city, area, duration, interests = interests.Distinct().Order(StringComparer.Ordinal).ToArray(), variant, version });
    public static string Nearby(GeoPoint p, string need, int radius) => Hash(new { location = LocationRounding.Round(p), need, radius });
}
public static class CacheTtl
{
    public static readonly TimeSpan Tour = TimeSpan.FromDays(7);
    public static readonly TimeSpan Place = TimeSpan.FromDays(7);
    public static readonly TimeSpan Nearby = TimeSpan.FromHours(24);
    public static readonly TimeSpan Wiki = TimeSpan.FromDays(30);
}
