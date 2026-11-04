using DiDau.Core.Abstractions;
using DiDau.Core.Geo;
using DiDau.Core.Places;
using DiDau.Infrastructure.Goong;
using DiDau.Infrastructure.Osm;

namespace DiDau.Infrastructure;

/// Search goes to Goong (suggestions, addresses); details are routed by ID prefix,
/// so OSM tour stops and Goong places can both be re-fetched through one interface.
public sealed class RoutingPlacesClient(GoongPlacesClient goong, OverpassClient osm) : IPlacesClient
{
    public Task<Place[]> NearbySearch(GeoPoint location, string[] types, int radiusMeters, CancellationToken ct = default) =>
        goong.NearbySearch(location, types, radiusMeters, ct);
    public Task<Place[]> TextSearch(string query, GeoPoint center, CancellationToken ct = default) =>
        goong.TextSearch(query, center, ct);
    public Task<Place?> GetDetails(string id, CancellationToken ct = default) =>
        id.StartsWith(OverpassClient.IdPrefix, StringComparison.Ordinal) ? osm.GetDetails(id, ct) : goong.GetDetails(id, ct);
}
