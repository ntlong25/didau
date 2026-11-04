using System.Text.Json;
using DiDau.Core.Geo;
using DiDau.Core.Places;

namespace DiDau.Core.Abstractions;

public interface IPlacesClient
{
    Task<Place[]> NearbySearch(GeoPoint location, string[] types, int radiusMeters, CancellationToken ct = default);
    Task<Place[]> TextSearch(string query, GeoPoint center, CancellationToken ct = default);
    Task<Place?> GetDetails(string id, CancellationToken ct = default);
}
/// Tourist attractions for tours and the famous-area list (OpenStreetMap).
/// Details for the returned IDs are resolved through <see cref="IPlacesClient.GetDetails"/>.
public interface IAttractionsClient
{
    Task<Place[]> Search(GeoPoint center, int radiusMeters, DiDau.Core.Tours.Interest[] interests, CancellationToken ct = default);
    Task<Place[]> Famous(GeoPoint center, int radiusMeters, CancellationToken ct = default);
}
public sealed record WikiMatch(string Id, string? VietnameseTitle, string? EnglishTitle);
public sealed record WikiSummary(string Title, string Text, string Url, string Language);
public interface IWikiClient
{
    Task<WikiMatch?> FindByNameNear(string name, GeoPoint location, CancellationToken ct = default);
    Task<WikiMatch?> FindById(string wikidataId, CancellationToken ct = default);
    Task<WikiSummary?> GetSummary(WikiMatch match, CancellationToken ct = default);
}
public interface INarrationClient
{
    Task<string> GenerateAsync(string prompt, JsonElement schema, CancellationToken ct = default);
}
public interface ICacheStore
{
    Task<T?> Get<T>(string table, string key, CancellationToken ct = default) where T : class;
    Task Set<T>(string table, string key, T value, TimeSpan ttl, CancellationToken ct = default) where T : class;
}
public interface IClock { DateTimeOffset UtcNow { get; } }
public sealed class SystemClock : IClock { public DateTimeOffset UtcNow => DateTimeOffset.UtcNow; }
