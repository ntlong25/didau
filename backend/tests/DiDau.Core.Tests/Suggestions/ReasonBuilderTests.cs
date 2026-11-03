using DiDau.Core.Suggestions;

namespace DiDau.Core.Tests.Suggestions;

public class ReasonBuilderTests
{
    [Fact]
    public void BreakfastSearchDoesNotIncludeGenericCafe() => Assert.DoesNotContain("cafe", NeedMapping.Types(Need.Breakfast));
    [Fact]
    public void MissingDataDoesNotInventNumbers() => Assert.DoesNotMatch(@"\d", ReasonBuilder.Build(TestData.Place(), null));
    [Fact]
    public void UsesOnlyAvailableEvidence()
    {
        var reason = ReasonBuilder.Build(TestData.Place() with { Rating = 4.5m, UserRatingCount = 120, EditorialSummary = "Quán có sân vườn." }, true);
        Assert.Contains("120", reason);
        Assert.Contains("sân vườn", reason);
        Assert.Contains("mở cửa", reason);
    }
}
