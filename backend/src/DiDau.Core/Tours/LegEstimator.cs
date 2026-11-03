using System.Globalization;
using DiDau.Core.Geo;

namespace DiDau.Core.Tours;
public static class LegEstimator
{
    public static Leg Estimate(GeoPoint a, GeoPoint b, int? fromOrder, int toOrder)
    {
        var distance = Geo.Geo.HaversineMeters(a, b) * 1.3;
        var walk = distance <= 1500;
        var url = string.Create(CultureInfo.InvariantCulture, $"https://www.google.com/maps/dir/?api=1&origin={a.Lat},{a.Lng}&destination={b.Lat},{b.Lng}&travelmode={(walk ? "walking" : "driving")}");
        return new(fromOrder, toOrder, walk ? TravelMode.Walk : TravelMode.Ride, (int)Math.Ceiling(distance),
            (int)Math.Ceiling(distance / (walk ? 4500 : 20000) * 60), url);
    }
}
