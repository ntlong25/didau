namespace DiDau.Core.Places;

// Sunday = 0; minutes since local midnight. CloseDay null means always open.
public sealed record WeeklyPeriod(int OpenDay, int OpenMinute, int? CloseDay, int CloseMinute);
public sealed record WeeklyHours(WeeklyPeriod[] Periods, string[] WeekdayDescriptions);
public sealed record OpeningState(bool? OpenNow, DateTimeOffset? NextOpenAt);

public static class OpeningHours
{
    public static OpeningState Evaluate(WeeklyHours? hours, DateTimeOffset at)
    {
        if (hours is null || hours.Periods.Length == 0) return new(null, null);
        if (hours.Periods.Any(p => p.CloseDay is null)) return new(true, null);
        // Vietnam is UTC+07 throughout the year (no daylight saving).
        var local = at.ToOffset(TimeSpan.FromHours(7));
        var sunday = new DateTimeOffset(local.Date.AddDays(-(int)local.DayOfWeek), local.Offset);
        DateTimeOffset? next = null;
        foreach (var period in hours.Periods)
        {
            for (var week = -1; week <= 1; week++)
            {
                var start = sunday.AddDays(week * 7 + period.OpenDay).AddMinutes(period.OpenMinute);
                var end = sunday.AddDays(week * 7 + period.CloseDay!.Value).AddMinutes(period.CloseMinute);
                if (end <= start) end = end.AddDays(7);
                if (local >= start && local < end) return new(true, null);
                if (start > local && (next is null || start < next)) next = start;
            }
        }
        return new(false, next);
    }

    public static bool ServesDinner(WeeklyHours? hours) => hours?.Periods.Any(p =>
        p.CloseDay is null || p.CloseDay != p.OpenDay || p.CloseMinute > 17 * 60) == true;
}
