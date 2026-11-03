using System.Text.Json.Serialization;
using DiDau.Core.Geo;
using DiDau.Core.Places;

namespace DiDau.Core.Tours;

public enum TourDuration { OneHour = 60, HalfDay = 240, FullDay = 480 }
public enum Interest { History, Food, Photo }
public enum TravelMode { Walk, Ride }
public enum TourStart { UserLocation, FirstStop }
public enum SectionKind { History, Trivia, Tips }
public enum FactKind { History, Description, PlaceData }
public sealed record TourRequest([property: JsonRequired] string CityId, [property: JsonRequired] TourDuration Duration,
    [property: JsonRequired] Interest[] Interests, string? AreaPlaceId = null, int Variant = 0, GeoPoint? UserLocation = null);
public sealed record SourceRef(string Title, string Url);
public sealed record Fact(string Id, string PlaceId, string Text, string SourceUrl, FactKind Kind, string Title);
public sealed record NarrationSection(SectionKind Kind, string Text, SourceRef[] Sources);
public sealed record TourStop(int Order, Place Place, int StayMinutes, NarrationSection[] Narration);
public sealed record Leg(int? FromOrder, int ToOrder, TravelMode Mode, int DistanceMeters, int Minutes, string DirectionsUrl);
public sealed record Route(TourStop[] Stops, Leg[] Legs, int TotalMinutes);
public sealed record CachedStop(string PlaceId, GeoPoint Location, int Order, int StayMinutes, NarrationSection[] Narration);
public sealed record CachedTour(CachedStop[] Stops, Fact[] Facts, DateTimeOffset GeneratedAt);
public sealed record Tour(string Id, string CityId, string? AreaPlaceId, TourDuration Duration, Interest[] Interests, int Variant,
    TourStart Start, TourStop[] Stops, Leg[] Legs, int TotalMinutes, DateTimeOffset GeneratedAt);
