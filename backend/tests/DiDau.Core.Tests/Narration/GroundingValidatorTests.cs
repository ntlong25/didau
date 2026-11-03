using System.Text.Json;
using DiDau.Core.Narration;
using DiDau.Core.Tours;

namespace DiDau.Core.Tests.Narration;
public class GroundingValidatorTests
{
    private static readonly Fact[] Facts = [new("f1", "p1", "Được xây năm 1900.", "https://example.org/a", FactKind.History, "Nguồn A"), new("f2", "p2", "Có 500 cây.", "https://example.org/b", FactKind.Description, "Nguồn B")];
    [Theory]
    [InlineData("p1", "Được xây năm 1900.", "f1", 1)]
    [InlineData("unknown", "Được xây năm 1900.", "f1", 0)]
    [InlineData("p1", "Được xây năm 1900.", "bad", 0)]
    [InlineData("p1", "Được xây năm 1999.", "f1", 0)]
    [InlineData("p1", "Gọi 0901234567.", "f1", 0)]
    [InlineData("p1", "Có 500 cây.", "f2", 0)]
    [InlineData("p1", "Nơi vua từng sống.", "f1", 0)]
    public void RejectsUnknownCrossPlaceAndInventedClaims(string place, string text, string source, int count)
    {
        var raw = JsonSerializer.Serialize(new { stops = new[] { new { placeId = place, sections = new[] { new { kind = "History", text, sourceIds = new[] { source } } } } } });
        var result = GroundingValidator.Validate(raw, ["p1"], Facts);
        Assert.Equal(count, result.Values.Sum(v => v.Length));
        if (count > 0) Assert.Equal("https://example.org/a", result["p1"][0].Sources[0].Url);
    }
    [Fact]
    public void EmptySourcesAndMalformedOutputAreDropped()
    {
        Assert.Empty(GroundingValidator.Validate("invalid", ["p1"], Facts));
        Assert.Empty(GroundingValidator.Validate("{\"stops\":[{\"placeId\":\"p1\",\"sections\":[{\"kind\":\"History\",\"text\":\"Được xây năm 1900.\",\"sourceIds\":[]}]}]}", ["p1"], Facts));
    }
}
