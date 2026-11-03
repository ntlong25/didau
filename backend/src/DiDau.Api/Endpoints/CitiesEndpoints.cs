using DiDau.Core.Cities;

namespace DiDau.Api.Endpoints;

public static class CitiesEndpoints
{
    public static void MapCities(this WebApplication app) => app.MapGet("/api/cities", () =>
        CityLocator.All.Select(c => new { c.Id, c.Name, c.Center }));
}
