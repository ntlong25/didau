using DiDau.Core.Geo;
using DiDau.Core.Tours;

namespace DiDau.Core.Tests.Tours;
public class LegEstimatorTests
{
    [Theory]
    [InlineData(21.0298, TravelMode.Walk, 4.5)]
    [InlineData(21.1288, TravelMode.Ride, 20)]
    public void UsesRoadFactorSpeedAndCeiling(double lat, TravelMode mode, double speed)
    {
        var a = new GeoPoint(21.0288, 105.852); var b = new GeoPoint(lat, 105.852);
        var leg = LegEstimator.Estimate(a, b, null, 1);
        var distance = Geo.Geo.HaversineMeters(a, b) * 1.3;
        Assert.Equal((int)Math.Ceiling(distance), leg.DistanceMeters);
        Assert.Equal((int)Math.Ceiling(distance / (speed * 1000) * 60), leg.Minutes);
        Assert.Equal(mode, leg.Mode);
        Assert.Contains("api=1&origin=", leg.DirectionsUrl);
        Assert.Contains(mode == TravelMode.Walk ? "travelmode=walking" : "travelmode=driving", leg.DirectionsUrl);
    }
}
