using System.Text.Json.Serialization;
using DiDau.Core.Geo;
using DiDau.Core.Places;

namespace DiDau.Core.Suggestions;

public enum Need { Coffee, Food, Breakfast, Dinner }
public sealed record SuggestionRequest([property: JsonRequired] GeoPoint Location, [property: JsonRequired] Need Need, int RadiusMeters = 2000);
public sealed record Suggestion(Place Place, string Reason, int DistanceMeters, bool? OpenNow, DateTimeOffset? NextOpenAt);
public sealed record SuggestionResult(string CityId, Suggestion[] Items, bool CanExpandRadius);
