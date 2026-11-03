using DiDau.Core;
using DiDau.Core.Abstractions;
using DiDau.Core.Cities;
using DiDau.Core.Places;

namespace DiDau.Api.Endpoints;
public static class GeocodeEndpoints
{
    public static void MapGeocode(this WebApplication app) => app.MapGet("/api/geocode", async (string q, string? cityId, IPlacesClient places, CancellationToken ct) =>
    {
        q = q.Trim();
        if (q.Length is < 2 or > 150) throw DomainException.Validation("Nhập địa chỉ từ 2 đến 150 ký tự.");
        var cities = cityId is null ? CityLocator.All : [CityLocator.Require(cityId)];
        var found = await Task.WhenAll(cities.Select(async city =>
            (await places.TextSearch(q + " " + city.Name, city.Center, ct))
                .Where(p => CityLocator.Contains(city, p.Location) && p.BusinessStatus != BusinessStatus.ClosedPermanently)
                .Select(p => new { label = string.IsNullOrWhiteSpace(p.Address) ? p.Name : p.Name + " — " + p.Address, p.Location, cityId = city.Id })));
        return Results.Ok(found.SelectMany(x => x).DistinctBy(x => x.Location).Take(5));
    }).RequireRateLimiting("suggestions");
}
