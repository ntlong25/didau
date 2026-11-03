using DiDau.Core.Geo;

namespace DiDau.Core.Cities;

public sealed record City(string Id, string Name, GeoPoint Center, GeoPoint[] Boundary);

public static class CityLocator
{
    // Deliberately simplified MVP coverage polygons, not authoritative administrative boundaries.
    public static IReadOnlyList<City> All { get; } = [
        new("hanoi", "Hà Nội", new(21.0288,105.852), [new(20.55,105.3),new(20.7,106.0),new(21.25,106.02),new(21.4,105.65),new(21.2,105.3)]),
        new("hcmc", "TP. Hồ Chí Minh", new(10.7769,106.7009), [new(10.35,106.5),new(10.4,106.98),new(10.9,106.92),new(11.15,106.5),new(10.9,106.35)]),
        new("dalat", "Đà Lạt", new(11.9404,108.4583), [new(11.85,108.3),new(11.85,108.58),new(12.08,108.58),new(12.08,108.3)]),
        new("nhatrang", "Nha Trang", new(12.2388,109.1967), [new(12.13,109.08),new(12.13,109.28),new(12.4,109.28),new(12.4,109.08)]),
        new("danang", "Đà Nẵng", new(16.0544,108.2022), [new(15.95,107.95),new(15.95,108.3),new(16.2,108.35),new(16.23,107.95)])
    ];

    public static City? Find(GeoPoint point) => point.IsValid ? All.FirstOrDefault(c => Contains(c, point)) : null;
    public static City Require(string id) => All.FirstOrDefault(c => c.Id == id) ?? throw DomainException.CityNotSupported();

    public static bool Contains(City city, GeoPoint point)
    {
        var inside = false;
        var polygon = city.Boundary;
        for (int i = 0, j = polygon.Length - 1; i < polygon.Length; j = i++)
        {
            var a = polygon[i]; var b = polygon[j];
            if ((a.Lat > point.Lat) != (b.Lat > point.Lat) &&
                point.Lng < (b.Lng - a.Lng) * (point.Lat - a.Lat) / (b.Lat - a.Lat) + a.Lng)
                inside = !inside;
        }
        return inside;
    }
}
