using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using DiDau.Core;
using DiDau.Core.Abstractions;
using DiDau.Api.Endpoints;
using DiDau.Infrastructure.GooglePlaces;
using DiDau.Infrastructure.Persistence;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
builder.Services.ConfigureHttpJsonOptions(o => o.SerializerOptions.Converters.Add(new JsonStringEnumConverter(allowIntegerValues: false)));
builder.Services.Configure<Microsoft.AspNetCore.Routing.RouteHandlerOptions>(o => o.ThrowOnBadRequest = true);
builder.Services.AddProblemDetails();
builder.Services.AddSingleton<IClock, SystemClock>();
builder.Services.AddScoped<DiDau.Core.Suggestions.SuggestionService>();
builder.Services.AddScoped(sp => new DiDau.Core.Tours.TourService(sp.GetRequiredService<IPlacesClient>(), sp.GetRequiredService<IWikiClient>(),
    sp.GetRequiredService<INarrationClient>(), sp.GetRequiredService<ICacheStore>(), sp.GetRequiredService<IClock>(), builder.Configuration["Narration:PromptVersion"] ?? "extractive-v1"));
builder.Services.AddDbContextFactory<DiDauDbContext>(o => o.UseNpgsql(builder.Configuration.GetConnectionString("Default") ?? "Host=localhost;Database=didau;Username=postgres"));
builder.Services.AddSingleton<ICacheStore, PostgresCacheStore>();
builder.Services.AddHostedService<CacheCleanupService>();
builder.Services.AddHttpClient("places", c => c.Timeout = TimeSpan.FromSeconds(5));
builder.Services.AddScoped<IPlacesClient>(sp => new GooglePlacesClient(sp.GetRequiredService<IHttpClientFactory>().CreateClient("places"),
    sp.GetRequiredService<IConfiguration>(), sp.GetRequiredService<IClock>()));
builder.Services.AddHttpClient<IWikiClient, DiDau.Infrastructure.Wiki.WikiClient>(c => c.Timeout = TimeSpan.FromSeconds(3));
builder.Services.AddHttpClient<INarrationClient, DiDau.Infrastructure.OpenAi.OpenAiNarrationClient>(c => c.Timeout = TimeSpan.FromSeconds(15));
builder.Logging.AddFilter("System.Net.Http.HttpClient", LogLevel.None);
builder.Logging.AddFilter("Microsoft.EntityFrameworkCore.Database.Command", LogLevel.None);
builder.Logging.AddFilter("Microsoft.AspNetCore.Diagnostics.ExceptionHandlerMiddleware", LogLevel.None);
builder.Logging.AddFilter("Microsoft.AspNetCore.Hosting.Diagnostics", LogLevel.Warning);
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
{
    var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
    if (origins.Length > 0) p.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod();
}));
builder.Services.AddRateLimiter(o =>
{
    foreach (var (name, limit) in new[] { ("suggestions", 30), ("tours", 5) })
        o.AddPolicy(name, context => RateLimitPartition.GetFixedWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions { PermitLimit = limit, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
    o.OnRejected = async (context, ct) =>
    {
        context.HttpContext.Response.StatusCode = 429;
        context.HttpContext.Response.Headers.RetryAfter = "60";
        await context.HttpContext.Response.WriteAsJsonAsync(new { code = "RATE_LIMITED", message = "Bạn thao tác quá nhanh. Hãy thử lại sau một phút." }, ct);
    };
});
var app = builder.Build();
if (builder.Configuration.GetValue<bool>("Database:MigrateOnStartup"))
{
    await using var db = await app.Services.GetRequiredService<IDbContextFactory<DiDauDbContext>>().CreateDbContextAsync();
    await db.Database.MigrateAsync();
}
app.UseExceptionHandler(handler => handler.Run(async context =>
{
    var error = context.Features.Get<IExceptionHandlerFeature>()?.Error;
    var (status, code, message) = error switch
    {
        DomainException e => (e.Code == "VALIDATION_ERROR" ? 400 : 422, e.Code, e.Message),
        BadHttpRequestException => (400, "VALIDATION_ERROR", "Dữ liệu không hợp lệ. Hãy kiểm tra các lựa chọn."),
        _ => (502, "UPSTREAM_ERROR", "Chưa thể lấy dữ liệu. Vui lòng thử lại sau.")
    };
    context.Response.StatusCode = status;
    await context.Response.WriteAsJsonAsync(new { type = "about:blank", title = message, status, code, message });
}));
app.UseCors();
app.UseRateLimiter();
app.MapCities();
app.MapSuggestions();
app.MapTours();
app.MapGeocode();
app.MapPlaces();
app.Run();

public partial class Program;
