using DiDau.Core.Places;
using DiDau.Core.Tours;

namespace DiDau.Core.Tests.Tours;
public class RouteBuilderTests
{
    private static Place[] Candidates() => Enumerable.Range(0, 30).Select(i => TestData.Place("p" + i, 21.0288 + i * .0001, i % 2 == 0 ? "historical_landmark" : "restaurant")).ToArray();
    [Theory]
    [InlineData(TourDuration.OneHour)]
    [InlineData(TourDuration.HalfDay)]
    [InlineData(TourDuration.FullDay)]
    public void StaysWithinBudgetAndDoesNotRepeat(TourDuration duration)
    {
        var points = Candidates();
        var result = RouteBuilder.Build([.. points, points[0], TestData.Place("closed") with { BusinessStatus = BusinessStatus.ClosedPermanently }], duration, [Interest.History, Interest.Food], 0);
        Assert.InRange(result.TotalMinutes, 1, (int)duration);
        Assert.Equal(result.Stops.Length, result.Stops.Select(s => s.Place.Id).Distinct().Count());
        Assert.DoesNotContain(result.Stops, s => s.Place.Id == "closed");
        Assert.Contains(result.Stops, s => s.Place.Types.Contains("restaurant"));
        Assert.Contains(result.Stops, s => s.Place.Types.Contains("historical_landmark"));
        if (duration == TourDuration.OneHour) Assert.InRange(result.Stops.Length, 2, 4);
    }
    [Fact]
    public void VariantChangesSetDeterministically()
    {
        string[] Set(int variant) => RouteBuilder.Build(Candidates(), TourDuration.OneHour, [Interest.History], variant).Stops.Select(s => s.Place.Id).ToArray();
        Assert.Equal(Set(1), Set(1)); Assert.NotEqual(Set(0), Set(1));
    }
    [Fact]
    public void IncludesInitialLegInBudget()
    {
        var result = RouteBuilder.Build(Candidates(), TourDuration.OneHour, [Interest.History], 0, new(21.1, 105.852));
        Assert.Null(result.Legs[0].FromOrder);
        Assert.Equal(result.Stops.Length, result.Legs.Length);
        Assert.Equal(result.TotalMinutes, result.Stops.Sum(s => s.StayMinutes) + result.Legs.Sum(l => l.Minutes));
        Assert.True(result.TotalMinutes <= 60);
    }
    [Fact]
    public void NoCandidatesIsExplicitError() => Assert.Throws<DomainException>(() => RouteBuilder.Build([], TourDuration.OneHour, [Interest.History], 0));
}
