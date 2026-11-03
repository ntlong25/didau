using Microsoft.EntityFrameworkCore;

namespace DiDau.Infrastructure.Persistence;

public sealed class CacheRow
{
    public string Key { get; set; } = "";
    public string Payload { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
}

public sealed class DiDauDbContext(DbContextOptions<DiDauDbContext> options) : DbContext(options)
{
    public static readonly string[] Tables = ["tour_cache", "nearby_cache", "wiki_cache"];
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        foreach (var table in Tables)
            modelBuilder.SharedTypeEntity<CacheRow>(table, entity =>
            {
                entity.ToTable(table);
                entity.HasKey(x => x.Key);
                entity.Property(x => x.Key).HasColumnName(table == "place_cache" ? "place_id" : "key");
                entity.Property(x => x.Payload).HasColumnName("payload").HasColumnType("jsonb");
                entity.Property(x => x.CreatedAt).HasColumnName(table == "place_cache" ? "fetched_at" : "created_at");
                entity.Property(x => x.ExpiresAt).HasColumnName("expires_at");
                entity.HasIndex(x => x.ExpiresAt);
            });
    }
}
