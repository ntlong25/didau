using DiDau.Core.Geo;

namespace DiDau.Core.Places;

public enum PriceLevel { Inexpensive, Moderate, Expensive, VeryExpensive }
public enum BusinessStatus { Operational, ClosedTemporarily, ClosedPermanently }

public sealed record Place(string Id, string Name, GeoPoint Location, string MapsUri, DateTimeOffset FetchedAt)
{
    public string? Address { get; init; }
    public string[] Types { get; init; } = [];
    public WeeklyHours? OpeningHours { get; init; }
    public PriceLevel? PriceLevel { get; init; }
    public decimal? Rating { get; init; }
    public int? UserRatingCount { get; init; }
    public BusinessStatus BusinessStatus { get; init; }
    public string? EditorialSummary { get; init; }
    public string? WikidataId { get; init; }
}
