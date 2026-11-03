using DiDau.Core.Places;

namespace DiDau.Core.Tests.Places;

public class OpeningHoursTests
{
    private static readonly WeeklyHours Hours = new([new(2, 8 * 60, 2, 22 * 60)], ["Thứ Ba: 08:00–22:00"]);

    [Theory]
    [InlineData("2026-11-03T10:00:00+07:00", true)]
    [InlineData("2026-11-03T22:00:00+07:00", false)]
    public void UsesVietnamTime(string at, bool expected) =>
        Assert.Equal(expected, OpeningHours.Evaluate(Hours, DateTimeOffset.Parse(at)).OpenNow);

    [Fact]
    public void FindsNextOpeningTomorrow()
    {
        var state = OpeningHours.Evaluate(Hours, DateTimeOffset.Parse("2026-11-02T23:00:00+07:00"));
        Assert.Equal(DateTimeOffset.Parse("2026-11-03T08:00:00+07:00"), state.NextOpenAt);
    }

    [Fact]
    public void HandlesOvernightAndWeekWrap()
    {
        var hours = new WeeklyHours([new(6, 22 * 60, 0, 2 * 60)], []);
        Assert.True(OpeningHours.Evaluate(hours, DateTimeOffset.Parse("2026-11-08T01:00:00+07:00")).OpenNow);
        Assert.False(OpeningHours.Evaluate(hours, DateTimeOffset.Parse("2026-11-08T02:00:00+07:00")).OpenNow);
    }

    [Fact]
    public void MissingIsUnknown() => Assert.Null(OpeningHours.Evaluate(null, DateTimeOffset.UtcNow).OpenNow);
}
