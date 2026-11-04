using DiDau.Core.Abstractions;
using DiDau.Core.Caching;
using DiDau.Core.Cities;
using DiDau.Core.Places;

namespace DiDau.Core.Suggestions;

public sealed class SuggestionService(IPlacesClient places, ICacheStore cache, IClock clock)
{
    public async Task<SuggestionResult> Get(SuggestionRequest request, CancellationToken ct = default)
    {
        if (request.Location is null || !request.Location.IsValid || !Enum.IsDefined(request.Need) || request.RadiusMeters is not (2000 or 5000))
            throw DomainException.Validation("Vị trí, nhu cầu hoặc bán kính không hợp lệ.");
        var city = CityLocator.Find(request.Location) ?? throw DomainException.CityNotSupported();
        var key = "goong-v2:" + CacheKey.Nearby(request.Location, request.Need.ToString(), request.RadiusMeters);
        var ids = await cache.Get<string[]>("nearby_cache", key, ct);
        Place[] candidates;
        if (ids is null)
        {
            // Search a slightly larger rounded circle, then enforce actual radius per request.
            candidates = await places.NearbySearch(LocationRounding.Round(request.Location), NeedMapping.Types(request.Need), request.RadiusMeters + 160, ct);
            candidates = candidates.Where(p => NeedMapping.Matches(p, request.Need)).ToArray();
            await cache.Set("nearby_cache", key, candidates.Select(p => p.Id).ToArray(), CacheTtl.Nearby, ct);
        }
        else candidates = (await Task.WhenAll(ids.Select(id => places.GetDetails(id, ct)))).OfType<Place>().ToArray();
        var items = candidates.DistinctBy(p => p.Id)
            // Goong details omit categories; cached membership retains the original keyword match.
            .Where(p => p.BusinessStatus != BusinessStatus.ClosedPermanently &&
                (NeedMapping.Matches(p, request.Need) || (ids is not null && p.Types.Length == 0 && ids.Contains(p.Id))))
            .Select(p =>
            {
                var state = p.BusinessStatus == BusinessStatus.ClosedTemporarily ? new OpeningState(false, null) : OpeningHours.Evaluate(p.OpeningHours, clock.UtcNow);
                return new Suggestion(p, ReasonBuilder.Build(p, state.OpenNow), (int)Math.Ceiling(Geo.Geo.HaversineMeters(request.Location, p.Location)), state.OpenNow, state.NextOpenAt);
            })
            .Where(s => s.DistanceMeters <= request.RadiusMeters)
            .OrderByDescending(s => s.OpenNow == true).ThenByDescending(s => s.Place.Rating ?? 0)
            .ThenBy(s => s.DistanceMeters).ThenBy(s => s.Place.Id, StringComparer.Ordinal).Take(5).ToArray();
        return new(city.Id, items, items.Length < 3 && request.RadiusMeters == 2000);
    }
}
