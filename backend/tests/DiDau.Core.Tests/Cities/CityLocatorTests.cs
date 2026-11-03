using DiDau.Core.Cities;
using DiDau.Core.Geo;

namespace DiDau.Core.Tests.Cities;

public class CityLocatorTests
{
    [Theory]
    [InlineData(21.0288, 105.852, "hanoi")]
    [InlineData(10.772, 106.698, "hcmc")]
    [InlineData(10.045, 105.747, null)]
    public void FindsSupportedCity(double lat, double lng, string? expected) =>
        Assert.Equal(expected, CityLocator.Find(new GeoPoint(lat, lng))?.Id);
}
