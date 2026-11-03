using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using DiDau.Core.Tours;

namespace DiDau.Core.Narration;
public static class GroundingValidator
{
    public static Dictionary<string, NarrationSection[]> Validate(string json, string[] placeIds, Fact[] facts)
    {
        var output = new Dictionary<string, NarrationSection[]>();
        try
        {
            using var document = JsonDocument.Parse(json);
            foreach (var stop in document.RootElement.GetProperty("stops").EnumerateArray())
            {
                var id = stop.GetProperty("placeId").GetString();
                if (id is null || !placeIds.Contains(id) || output.ContainsKey(id)) continue;
                var sections = new List<NarrationSection>();
                foreach (var section in stop.GetProperty("sections").EnumerateArray())
                {
                    if (!Enum.TryParse<SectionKind>(section.GetProperty("kind").GetString(), out var kind) || !Enum.IsDefined(kind)) continue;
                    var text = section.GetProperty("text").GetString();
                    var ids = section.GetProperty("sourceIds").EnumerateArray().Select(s => s.GetString()).Distinct().ToArray();
                    if (string.IsNullOrWhiteSpace(text) || ids.Length == 0) continue;
                    var sources = facts.Where(f => f.PlaceId == id && ids.Contains(f.Id)).ToArray();
                    if (sources.Length != ids.Length || sources.Any(f => !Uri.TryCreate(f.SourceUrl, UriKind.Absolute, out var uri) || uri.Scheme != "https")) continue;
                    if (kind == SectionKind.History && !sources.Any(f => f.Kind == FactKind.History)) continue;
                    var sourceNumbers = sources.SelectMany(f => Regex.Matches(f.Text, @"\d+").Select(m => m.Value)).ToHashSet();
                    if (Regex.Matches(text, @"\d+").Any(m => !sourceNumbers.Contains(m.Value))) continue;
                    // Source IDs and matching numbers alone cannot prove a claim. Accept only extractive text.
                    var normalized = Normalize(text);
                    if (!sources.Any(f => Normalize(f.Text).Contains(normalized, StringComparison.Ordinal))) continue;
                    sections.Add(new(kind, text, sources.Select(f => new SourceRef(f.Title, f.SourceUrl)).ToArray()));
                }
                if (sections.Count > 0) output[id] = sections.DistinctBy(s => (s.Kind, s.Text)).ToArray();
            }
        }
        catch (Exception e) when (e is JsonException or InvalidOperationException or KeyNotFoundException or ArgumentException) { return []; }
        return output;
    }
    private static string Normalize(string value) => Regex.Replace(value.Normalize(NormalizationForm.FormC).Trim(), @"\s+", " ");
}
