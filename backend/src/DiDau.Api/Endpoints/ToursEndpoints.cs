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
        app.MapGet("/api/cities/{cityId}/areas", async (string cityId, string? q, IAttractionsClient attractions, CancellationToken ct) =>
        {
            var city = CityLocator.All.FirstOrDefault(c => c.Id == cityId);
            if (city is null) return Results.NotFound(new { code = "CITY_NOT_SUPPORTED", message = DomainException.CityNotSupported().Message });
            q = q?.Trim() ?? "";
            if (q.Length > 150) throw DomainException.Validation("Tên khu vực quá dài.");
            // Famous areas come from OSM (cached by the adapter); the user's text only filters by name.
            var items = (await attractions.Famous(city.Center, 8000, ct))
                .Where(p => CityLocator.Contains(city, p.Location) && (q.Length == 0 || p.Name.Contains(q, StringComparison.OrdinalIgnoreCase)))
                .Take(30);
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
