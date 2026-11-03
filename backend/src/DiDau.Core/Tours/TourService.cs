using DiDau.Core.Abstractions;
using DiDau.Core.Caching;
using DiDau.Core.Cities;
using DiDau.Core.Narration;
using DiDau.Core.Places;

namespace DiDau.Core.Tours;
public sealed class TourService(IPlacesClient places, IWikiClient wiki, INarrationClient ai, ICacheStore cache, IClock clock, string promptVersion)
{
    public async Task<Tour> Get(TourRequest request, CancellationToken ct = default)
    {
        var city = CityLocator.Require(request.CityId);
        if (!Enum.IsDefined(request.Duration) || request.Interests is null || request.Interests.Length == 0 || request.Interests.Any(i => !Enum.IsDefined(i)) || request.Variant < 0 || request.UserLocation is { IsValid: false })
            throw DomainException.Validation("Hãy chọn thời lượng, sở thích và vị trí hợp lệ.");
        var interests = request.Interests.Distinct().Order().ToArray();
        var key = CacheKey.Tour(city.Id, request.AreaPlaceId, request.Duration.ToString(), interests.Select(i => i.ToString()), request.Variant, "wiki-only-v2:" + promptVersion);
        var cached = await cache.Get<CachedTour>("tour_cache", key, ct);
        if (cached is null)
        {
            var center = city.Center;
            var areaName = city.Name;
            if (!string.IsNullOrWhiteSpace(request.AreaPlaceId))
            {
                var area = await places.GetDetails(request.AreaPlaceId, ct);
                if (area is null || !CityLocator.Contains(city, area.Location)) throw DomainException.InsufficientData();
                center = area.Location; areaName = area.Name + " " + city.Name;
            }
            var queries = interests.Select(i => (i switch { Interest.History => "di tích bảo tàng ", Interest.Food => "ẩm thực nhà hàng ", _ => "điểm tham quan công viên " }) + areaName);
            var candidates = (await Task.WhenAll(queries.Select(q => places.TextSearch(q, center, ct)))).SelectMany(p => p)
                .Where(p => CityLocator.Contains(city, p.Location)).DistinctBy(p => p.Id).ToArray();
            var route = RouteBuilder.Build(candidates, request.Duration, interests, request.Variant);
            var facts = new List<Fact>();
            // Bound concurrent Wiki requests to avoid overwhelming public infrastructure.
            using var gate = new SemaphoreSlim(4);
            var wikiFacts = await Task.WhenAll(route.Stops.Select(async stop =>
            {
                await gate.WaitAsync(ct);
                try
                {
                    var match = await wiki.FindByNameNear(stop.Place.Name, stop.Place.Location, ct);
                    var summary = match is null ? null : await wiki.GetSummary(match, ct);
                    // English fallback is retained by the adapter, but never presented as Vietnamese narration.
                    return summary is { Language: "vi" } ? new Fact(stop.Place.Id + "-wiki", stop.Place.Id, summary.Text, summary.Url, FactKind.History, summary.Title) : null;
                }
                catch (HttpRequestException) { return null; }
                catch (TaskCanceledException) when (!ct.IsCancellationRequested) { return null; }
                finally { gate.Release(); }
            }));
            facts.AddRange(wikiFacts.OfType<Fact>());
            Dictionary<string, NarrationSection[]> narration = [];
            if (facts.Count > 0)
            {
                var raw = await ai.GenerateAsync(PromptBuilder.Build(route.Stops.Select(s => s.Place).ToArray(), facts.ToArray()), PromptBuilder.Schema, ct);
                narration = GroundingValidator.Validate(raw, route.Stops.Select(s => s.Place.Id).ToArray(), facts.ToArray());
            }
            cached = new(route.Stops.Select(s => new CachedStop(s.Place.Id, s.Place.Location, s.Order, s.StayMinutes,
                narration.GetValueOrDefault(s.Place.Id) ?? [])).ToArray(), facts.ToArray(), clock.UtcNow);
            await cache.Set("tour_cache", key, cached, CacheTtl.Tour, ct);
        }
        // Details are always hydrated for this request, including on a tour-cache hit.
        var hydrated = await Task.WhenAll(cached.Stops.OrderBy(s => s.Order).Select(async stop =>
        {
            var place = await places.GetDetails(stop.PlaceId, ct);
            return place is null || place.BusinessStatus == BusinessStatus.ClosedPermanently || !CityLocator.Contains(city, place.Location)
                ? null : new TourStop(stop.Order, place, stop.StayMinutes, stop.Narration);
        }));
        var stops = new List<TourStop>(); var legs = new List<Leg>(); var total = 0;
        foreach (var stop in hydrated.OfType<TourStop>())
        {
            var leg = stops.Count == 0 ? null : LegEstimator.Estimate(stops[^1].Place.Location, stop.Place.Location, stops.Count, stops.Count + 1);
            if (total + stop.StayMinutes + (leg?.Minutes ?? 0) > (int)request.Duration) continue;
            stops.Add(stop with { Order = stops.Count + 1 });
            if (leg is not null) legs.Add(leg);
            total += stop.StayMinutes + (leg?.Minutes ?? 0);
        }
        if (stops.Count == 0) throw DomainException.InsufficientData();
        var tour = new Tour(key, city.Id, request.AreaPlaceId, request.Duration, interests, request.Variant, TourStart.FirstStop,
            stops.ToArray(), legs.ToArray(), total, cached.GeneratedAt);
        if (request.UserLocation is { } origin && CityLocator.Contains(city, origin))
        {
            var route = RouteBuilder.Build(tour.Stops.Select(s => s.Place), tour.Duration, tour.Interests, 0, origin, tour.Stops.ToDictionary(s => s.Place.Id, s => s.Narration));
            return tour with { Start = TourStart.UserLocation, Stops = route.Stops, Legs = route.Legs, TotalMinutes = route.TotalMinutes };
        }
        return tour;
    }
}
