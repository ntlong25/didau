using System.Net;
using System.Text.Json;
using DiDau.Core.Abstractions;
using DiDau.Core.Caching;
using DiDau.Core.Geo;
using Microsoft.Extensions.Configuration;

namespace DiDau.Infrastructure.Wiki;
public sealed class WikiClient(HttpClient http, ICacheStore cache, IConfiguration config) : IWikiClient
{
    private sealed record MatchResult(WikiMatch? Match);
    public async Task<WikiMatch?> FindByNameNear(string name, GeoPoint location, CancellationToken ct = default)
    {
        var key = "match:" + CacheKey.Hash(new { name, location = LocationRounding.Round(location) });
        var cached = await cache.Get<MatchResult>("wiki_cache", key, ct);
        if (cached is not null) return cached.Match;
        using var search = await GetJson("https://www.wikidata.org/w/api.php?action=wbsearchentities&format=json&language=vi&uselang=vi&limit=5&search=" + Uri.EscapeDataString(name), ct);
        if (search is null || !search.RootElement.TryGetProperty("search", out var hits)) return null;
        var ids = hits.EnumerateArray().Select(h => h.GetProperty("id").GetString()!).Where(id => System.Text.RegularExpressions.Regex.IsMatch(id, "^Q[0-9]+$")).ToArray();
        WikiMatch? match = null;
        if (ids.Length > 0)
        {
            using var entities = await GetJson("https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=claims%7Csitelinks&ids=" + string.Join("%7C", ids), ct);
            if (entities is not null)
                foreach (var id in ids)
                {
                    var entity = entities.RootElement.GetProperty("entities").GetProperty(id);
                    if (!entity.TryGetProperty("claims", out var claims) || !claims.TryGetProperty("P625", out var coordinates)) continue;
                    var near = coordinates.EnumerateArray().Any(c =>
                    {
                        var snak = c.GetProperty("mainsnak");
                        if (!snak.TryGetProperty("datavalue", out var value)) return false;
                        var point = value.GetProperty("value");
                        return Geo.HaversineMeters(location, new(point.GetProperty("latitude").GetDouble(), point.GetProperty("longitude").GetDouble())) <= 500;
                    });
                    if (!near || !entity.TryGetProperty("sitelinks", out var links)) continue;
                    string? Title(string key) => links.TryGetProperty(key, out var link) ? link.GetProperty("title").GetString() : null;
                    match = new(id, Title("viwiki"), Title("enwiki"));
                    break;
                }
        }
        await cache.Set("wiki_cache", key, new MatchResult(match), CacheTtl.Wiki, ct);
        return match;
    }

    public async Task<WikiMatch?> FindById(string wikidataId, CancellationToken ct = default)
    {
        if (!System.Text.RegularExpressions.Regex.IsMatch(wikidataId, "^Q[0-9]+$")) return null;
        var key = "id:" + wikidataId;
        var cached = await cache.Get<MatchResult>("wiki_cache", key, ct);
        if (cached is not null) return cached.Match;
        using var entities = await GetJson("https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=sitelinks&ids=" + wikidataId, ct);
        WikiMatch? match = null;
        if (entities is not null && entities.RootElement.GetProperty("entities").TryGetProperty(wikidataId, out var entity)
            && entity.TryGetProperty("sitelinks", out var links))
        {
            string? Title(string site) => links.TryGetProperty(site, out var link) ? link.GetProperty("title").GetString() : null;
            match = new(wikidataId, Title("viwiki"), Title("enwiki"));
        }
        await cache.Set("wiki_cache", key, new MatchResult(match), CacheTtl.Wiki, ct);
        return match;
    }

    public async Task<WikiSummary?> GetSummary(WikiMatch match, CancellationToken ct = default)
    {
        var cached = await cache.Get<WikiSummary>("wiki_cache", match.Id, ct);
        if (cached is not null) return cached;
        foreach (var (language, title) in new[] { ("vi", match.VietnameseTitle), ("en", match.EnglishTitle) })
        {
            if (string.IsNullOrWhiteSpace(title)) continue;
            using var json = await GetJson($"https://{language}.wikipedia.org/api/rest_v1/page/summary/{Uri.EscapeDataString(title)}", ct);
            if (json is null || !json.RootElement.TryGetProperty("extract", out var extract)) continue;
            if (json.RootElement.TryGetProperty("type", out var type) && type.GetString() == "disambiguation") continue;
            var text = extract.GetString();
            if (string.IsNullOrWhiteSpace(text)) continue;
            var summary = new WikiSummary(title, text, $"https://{language}.wikipedia.org/wiki/{Uri.EscapeDataString(title)}", language);
            await cache.Set("wiki_cache", match.Id, summary, CacheTtl.Wiki, ct);
            return summary;
        }
        return null;
    }
    private async Task<JsonDocument?> GetJson(string url, CancellationToken ct)
    {
        var userAgent = config["Wiki:UserAgent"];
        if (string.IsNullOrWhiteSpace(userAgent)) throw new HttpRequestException("Wiki contact User-Agent is not configured.");
        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        request.Headers.TryAddWithoutValidation("User-Agent", userAgent);
        using var response = await http.SendAsync(request, ct);
        if (response.StatusCode == HttpStatusCode.NotFound) return null;
        response.EnsureSuccessStatusCode();
        return JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
    }
}
