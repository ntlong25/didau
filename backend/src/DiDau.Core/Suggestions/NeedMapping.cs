using DiDau.Core.Places;

namespace DiDau.Core.Suggestions;

public static class NeedMapping
{
    public static string[] Types(Need need) => need switch
    {
        Need.Coffee => ["cafe", "coffee_shop"], Need.Breakfast => ["breakfast_restaurant", "brunch_restaurant"], _ => ["restaurant"]
    };
    public static bool Matches(Place place, Need need) => need switch
    {
        Need.Breakfast => place.Types.Intersect(new[] { "breakfast_restaurant", "brunch_restaurant" }).Any(),
        Need.Dinner => place.Types.Contains("restaurant") && OpeningHours.ServesDinner(place.OpeningHours),
        _ => place.Types.Intersect(Types(need)).Any()
    };
}
