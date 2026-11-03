using DiDau.Core.Places;

namespace DiDau.Api.Endpoints;

public static class PlaceResponse
{
    public static object From(Place p, DateTimeOffset now)
    {
        var state = p.BusinessStatus == BusinessStatus.ClosedTemporarily ? new OpeningState(false, null) : OpeningHours.Evaluate(p.OpeningHours, now);
        return new { p.Id, p.Name, p.Address, p.Location, openingHoursText = p.OpeningHours?.WeekdayDescriptions,
            state.OpenNow, state.NextOpenAt, p.PriceLevel, p.Rating, p.UserRatingCount, p.MapsUri, p.FetchedAt };
    }
}
