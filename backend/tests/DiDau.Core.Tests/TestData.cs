using DiDau.Core.Geo;
using DiDau.Core.Places;

namespace DiDau.Core.Tests;

public static class TestData
{
    public static readonly DateTimeOffset Now = DateTimeOffset.Parse("2026-11-03T10:00:00+07:00");
    public static Place Place(string id = "p1", double lat = 21.0288, string type = "cafe") =>
        new(id, "Điểm " + id, new GeoPoint(lat, 105.852), "https://maps.google.com/?q=" + id, Now)
        { Types = [type], OpeningHours = new([new(2, 8 * 60, 2, 22 * 60)], ["08:00–22:00"]) };
}
