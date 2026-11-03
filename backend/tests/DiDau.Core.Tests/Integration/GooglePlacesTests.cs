using System.Text.Json;
using DiDau.Core.Places;
using DiDau.Infrastructure.GooglePlaces;

namespace DiDau.Core.Tests.Integration;
public class GooglePlacesTests
{
    [Fact]
    public void MapsSourceDataAndDoesNotInventMissingValues()
    {
        using var json = JsonDocument.Parse("""
        {"id":"p1","displayName":{"text":"Quán"},"location":{"latitude":21,"longitude":105},"types":["cafe"],"businessStatus":"CLOSED_PERMANENTLY","regularOpeningHours":{"periods":[{"open":{"day":6,"hour":22},"close":{"day":0,"hour":2}}],"weekdayDescriptions":["Thứ Bảy: 22:00–02:00"]},"priceLevel":"PRICE_LEVEL_MODERATE","rating":4.5,"userRatingCount":100}
        """);
        var place = GooglePlacesClient.Map(json.RootElement, TestData.Now);
        Assert.Equal(BusinessStatus.ClosedPermanently, place.BusinessStatus);
        Assert.Equal(PriceLevel.Moderate, place.PriceLevel); Assert.Equal(4.5m, place.Rating);
        Assert.Null(place.Address); Assert.Null(place.EditorialSummary);
        Assert.Equal(0, place.OpeningHours!.Periods[0].CloseDay);
        Assert.Equal(TestData.Now, place.FetchedAt);
    }
}
