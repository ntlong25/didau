using System.Text.Json;
using System.Text.Json.Serialization;
using DiDau.Core.Abstractions;
using Microsoft.EntityFrameworkCore;

namespace DiDau.Infrastructure.Persistence;

public sealed class PostgresCacheStore(IDbContextFactory<DiDauDbContext> factory, IClock clock) : ICacheStore
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { Converters = { new JsonStringEnumConverter() } };
    public async Task<T?> Get<T>(string table, string key, CancellationToken ct = default) where T : class
    {
        Validate(table);
        await using var db = await factory.CreateDbContextAsync(ct);
        var now = clock.UtcNow;
        var row = await db.Set<CacheRow>(table).AsNoTracking().FirstOrDefaultAsync(x => x.Key == key && x.ExpiresAt > now, ct);
        return row is null ? null : JsonSerializer.Deserialize<T>(row.Payload, Json);
    }

    public async Task Set<T>(string table, string key, T value, TimeSpan ttl, CancellationToken ct = default) where T : class
    {
        Validate(table);
        await using var db = await factory.CreateDbContextAsync(ct);
        var keyColumn = table == "place_cache" ? "place_id" : "key";
        var createdColumn = table == "place_cache" ? "fetched_at" : "created_at";
        // Identifiers come exclusively from the allowlist; all values are parameters.
        var sql = $"INSERT INTO {table} ({keyColumn},payload,{createdColumn},expires_at) VALUES ({{0}},{{1}}::jsonb,{{2}},{{3}}) ON CONFLICT ({keyColumn}) DO UPDATE SET payload=EXCLUDED.payload,{createdColumn}=EXCLUDED.{createdColumn},expires_at=EXCLUDED.expires_at";
        await db.Database.ExecuteSqlRawAsync(sql, [key, JsonSerializer.Serialize(value, Json), clock.UtcNow, clock.UtcNow.Add(ttl)], ct);
    }
    private static void Validate(string table)
    {
        if (!DiDauDbContext.Tables.Contains(table)) throw new ArgumentException("Unknown cache table", nameof(table));
    }
}
