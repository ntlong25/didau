using DiDau.Core.Geo;
using DiDau.Core.Places;

namespace DiDau.Core.Tours;
public static class RouteBuilder
{
    public static bool Matches(Place p, Interest interest) => interest switch
    {
        Interest.Food => p.Types.Any(t => t is "restaurant" or "cafe" or "food" or "market"),
        Interest.History => p.Types.Any(t => t is "museum" or "historical_landmark" or "cultural_landmark" or "place_of_worship") || p.WikidataId is not null,
        _ => p.Types.Any(t => t is "tourist_attraction" or "park" or "historical_landmark" or "natural_feature" or "museum")
    };
    public static Route Build(IEnumerable<Place> candidates, TourDuration duration, Interest[] interests, int variant,
        GeoPoint? origin = null, IReadOnlyDictionary<string, NarrationSection[]>? narration = null)
    {
        var ranked = candidates.Where(p => p.BusinessStatus != BusinessStatus.ClosedPermanently).DistinctBy(p => p.Id)
            .OrderByDescending(p => interests.Count(i => Matches(p, i)) * 10 + (p.WikidataId is null ? 0 : 2) + (double)(p.Rating ?? 0) + Math.Log10(1 + (p.UserRatingCount ?? 0)))
            .ThenBy(p => p.Id, StringComparer.Ordinal).ToArray();
        if (ranked.Length == 0) throw DomainException.InsufficientData();
        var offset = variant % ranked.Length;
        var pool = ranked.Skip(offset).Concat(ranked.Take(offset)).ToList();
        var stops = new List<TourStop>(); var legs = new List<Leg>();
        var uncovered = interests.Distinct().ToHashSet();
        var total = 0; var current = origin;
        while (pool.Count > 0)
        {
            // First cover requested interests; then choose the nearest next stop.
            var eligible = pool.Where(p => uncovered.Any(i => Matches(p, i))).ToArray();
            if (eligible.Length == 0) eligible = pool.ToArray();
            var next = current is null ? eligible[0] : eligible.OrderBy(p => Geo.Geo.HaversineMeters(current, p.Location)).First();
            pool.Remove(next);
            var stay = duration == TourDuration.OneHour ? 20 : next.Types.Contains("museum") ? 60 : next.Types.Contains("restaurant") ? 45 : 30;
            var leg = current is null ? null : LegEstimator.Estimate(current, next.Location, stops.Count == 0 ? null : stops.Count, stops.Count + 1);
            if (total + stay + (leg?.Minutes ?? 0) > (int)duration) continue;
            total += stay + (leg?.Minutes ?? 0);
            stops.Add(new(stops.Count + 1, next, stay, narration?.GetValueOrDefault(next.Id) ?? []));
            if (leg is not null) legs.Add(leg);
            uncovered.RemoveWhere(i => Matches(next, i));
            current = next.Location;
        }
        if (stops.Count == 0) throw DomainException.InsufficientData();
        return new(stops.ToArray(), legs.ToArray(), total);
    }
}
