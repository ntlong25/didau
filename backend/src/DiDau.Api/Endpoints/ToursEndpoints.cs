using DiDau.Core;
using DiDau.Core.Abstractions;
using DiDau.Core.Caching;
using DiDau.Core.Cities;
using DiDau.Core.Tours;

namespace DiDau.Api.Endpoints;
public static class ToursEndpoints
{
    public static void MapTours(this WebApplication app)
    {
        app.MapGet("/api/cities/{cityId}/areas", async (string cityId, string? q, IPlacesClient places, ICacheStore cache, CancellationToken ct) =>
        {
            var city = CityLocator.All.FirstOrDefault(c => c.Id == cityId);
            if (city is null) return Results.NotFound(new { code = "CITY_NOT_SUPPORTED", message = DomainException.CityNotSupported().Message });
            q = q?.Trim() ?? "";
            if (q.Length > 150) throw DomainException.Validation("Tên khu vực quá dài.");
            // User-entered address queries are not persisted; only the public default area list is cached.
            var key = "areas:" + cityId;
            var ids = q.Length == 0 ? await cache.Get<string[]>("nearby_cache", key, ct) : null;
            var items = ids is null
                ? await places.TextSearch((q.Length == 0 ? "địa điểm nổi tiếng" : q) + " " + city.Name, city.Center, ct)
                : (await Task.WhenAll(ids.Select(id => places.GetDetails(id, ct)))).OfType<DiDau.Core.Places.Place>().ToArray();
            items = items.Where(p => CityLocator.Contains(city, p.Location) && p.BusinessStatus != DiDau.Core.Places.BusinessStatus.ClosedPermanently).ToArray();
            if (q.Length == 0 && ids is null) await cache.Set("nearby_cache", key, items.Select(p => p.Id).ToArray(), CacheTtl.Nearby, ct);
            return Results.Ok(items.Select(p => new { p.Id, p.Name, p.Address, p.Location }));
        }).RequireRateLimiting("suggestions");
        app.MapPost("/api/tours", async (TourRequest request, TourService service, IClock clock, CancellationToken ct) =>
        {
            using var budget = CancellationTokenSource.CreateLinkedTokenSource(ct);
            budget.CancelAfter(TimeSpan.FromSeconds(20));
            var tour = await service.Get(request, budget.Token);
            return Results.Ok(new { tour.Id, tour.CityId, tour.AreaPlaceId, tour.Duration, tour.Interests, tour.Variant,
                tour.Start, stops = tour.Stops.Select(s => new { s.Order, place = PlaceResponse.From(s.Place, clock.UtcNow), s.StayMinutes, s.Narration }),
                tour.Legs, tour.TotalMinutes, tour.GeneratedAt });
        }).RequireRateLimiting("tours");
    }
}
