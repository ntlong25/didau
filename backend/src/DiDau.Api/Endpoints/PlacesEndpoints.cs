using DiDau.Core.Abstractions;

namespace DiDau.Api.Endpoints;
public static class PlacesEndpoints
{
    // Saved items on the device only keep place IDs (Places terms 5.4), so the app re-fetches details here.
    public static void MapPlaces(this WebApplication app) => app.MapGet("/api/places/{placeId}", async (string placeId, IPlacesClient places, IClock clock, CancellationToken ct) =>
    {
        var place = await places.GetDetails(placeId, ct);
        return place is null
            ? Results.NotFound(new { code = "NOT_FOUND", message = "Không tìm thấy địa điểm này nữa." })
            : Results.Ok(PlaceResponse.From(place, clock.UtcNow));
    }).RequireRateLimiting("suggestions");
}
