using DiDau.Core.Abstractions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace DiDau.Infrastructure.Persistence;

public sealed class CacheCleanupService(IDbContextFactory<DiDauDbContext> factory, IClock clock, ILogger<CacheCleanupService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromDays(1));
        do
        {
            try
            {
                await using var db = await factory.CreateDbContextAsync(stoppingToken);
                var now = clock.UtcNow;
                foreach (var table in DiDauDbContext.Tables)
                    await db.Set<CacheRow>(table).Where(x => x.ExpiresAt <= now).ExecuteDeleteAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { return; }
            catch (Exception) { logger.LogWarning("Cache cleanup unavailable; will retry next cycle."); }
        } while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
