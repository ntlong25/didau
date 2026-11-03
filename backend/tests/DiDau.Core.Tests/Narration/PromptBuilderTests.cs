using DiDau.Core.Narration;
using DiDau.Core.Tours;

namespace DiDau.Core.Tests.Narration;
public class PromptBuilderTests
{
    [Fact]
    public void OnlyProvidedStopsAndFactsWithSourceSchema()
    {
        var prompt = PromptBuilder.Build([TestData.Place()], [new("f1", "p1", "Một khu vườn.", "https://example.org/source", FactKind.Description, "Nguồn")]);
        Assert.Contains("tiếng Việt", prompt); Assert.Contains("sourceIds", prompt);
        Assert.Contains("không viết địa chỉ", prompt); Assert.Contains("https://example.org/source", prompt);
        Assert.Contains("allowedKinds", prompt); Assert.DoesNotContain("\"History\"", prompt);
        Assert.Contains("placeId", PromptBuilder.Schema.GetRawText());
    }
}
