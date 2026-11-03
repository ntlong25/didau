using System.Text.Json.Serialization;

namespace DiDau.Core.Geo;

public sealed record GeoPoint(
    [property: JsonRequired] double Lat,
    [property: JsonRequired] double Lng)
{
    [JsonIgnore]
    public bool IsValid => double.IsFinite(Lat) && double.IsFinite(Lng) && Lat is >= -90 and <= 90 && Lng is >= -180 and <= 180;
}

public static class Geo
{
    public static double HaversineMeters(GeoPoint a, GeoPoint b)
    {
        const double radians = Math.PI / 180;
        var h = Math.Pow(Math.Sin((b.Lat - a.Lat) * radians / 2), 2) +
                Math.Cos(a.Lat * radians) * Math.Cos(b.Lat * radians) * Math.Pow(Math.Sin((b.Lng - a.Lng) * radians / 2), 2);
        return 6371000 * 2 * Math.Asin(Math.Sqrt(Math.Clamp(h, 0, 1)));
    }
}
