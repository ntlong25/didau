using DiDau.Core.Abstractions;
using DiDau.Core.Suggestions;

namespace DiDau.Api.Endpoints;

public static class SuggestionsEndpoints
{
    public static void MapSuggestions(this WebApplication app) => app.MapPost("/api/suggestions", async (SuggestionRequest request, SuggestionService service, IClock clock, CancellationToken ct) =>
    {
        var result = await service.Get(request, ct);
        return Results.Ok(new { result.CityId, result.CanExpandRadius, items = result.Items.Select(s => new { place = PlaceResponse.From(s.Place, clock.UtcNow), s.Reason, s.DistanceMeters }) });
    }).RequireRateLimiting("suggestions");
}
