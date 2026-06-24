using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure;
using SRJBackend.Infrastructure.Models;
using SRJBackend.Infrastructure.Queries;
using SRJBackend.Infrastructure.Repositories;
using SRJBackend.Infrastructure.Services;

// -----------------------------------------------------------------------------
// Tuition time-simulator.
// A dev-only console that drives the SAME GenerateMonthlyTuitionUseCase as the
// production scheduler, but against a VirtualClock you advance by command. This
// lets you fast-forward through a school year and watch one tuition debt appear
// per active enrollment per month, without waiting for real month boundaries.
// -----------------------------------------------------------------------------

// Locate the main project root (where appsettings.json / .env live) by climbing up.
var appRoot = FindAppRoot();
if (appRoot is null)
{
    Console.Error.WriteLine("Could not locate the SRJBackend project root (appsettings.json).");
    return 1;
}

var envPath = Path.Combine(appRoot, ".env");
if (File.Exists(envPath))
    DotNetEnv.Env.Load(envPath);

var config = new ConfigurationBuilder()
    .SetBasePath(appRoot)
    .AddJsonFile("appsettings.json", optional: true)
    .AddEnvironmentVariables()
    .Build();

var connectionString = config.GetConnectionString("DefaultConnection");
if (string.IsNullOrWhiteSpace(connectionString))
{
    Console.Error.WriteLine("No ConnectionStrings:DefaultConnection found (check .env).");
    return 1;
}

// The virtual clock we control. Starts at real 'today'; advance it with commands.
var clock = new VirtualClock();

var services = new ServiceCollection();
// SRJDbContext.OnConfiguring uses UseNpgsql("Name=ConnectionStrings:DefaultConnection"),
// so EF needs IConfiguration in the container to resolve the real connection string.
services.AddSingleton<IConfiguration>(config);
services.AddDbContext<SRJDbContext>(o => o.UseNpgsql(connectionString));
services.AddSingleton<IClock>(clock);
services.AddScoped<IUnitOfWork, UnitOfWork>();
services.AddScoped<IEnrollmentDebtRepository, EnrollmentDebtRepository>();
services.AddScoped<IBillingDataQueries, BillingDataQueries>();
services.AddScoped<GenerateMonthlyTuitionUseCase>();

await using var provider = services.BuildServiceProvider();

PrintHelp();
Console.WriteLine($"Virtual clock starts at {clock.Today:yyyy-MM-dd}.");

while (true)
{
    Console.Write("\nsim> ");
    var line = Console.ReadLine();
    if (line is null) break;

    var parts = line.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries);
    if (parts.Length == 0) continue;
    var cmd = parts[0].ToLowerInvariant();

    switch (cmd)
    {
        case "now":
            Console.WriteLine($"Virtual date: {clock.Today:yyyy-MM-dd}");
            break;

        case "+1d":
        case "+d":
            clock.AdvanceDays(ParseCount(parts));
            Console.WriteLine($"-> {clock.Today:yyyy-MM-dd}");
            break;

        case "+1m":
        case "+m":
            clock.AdvanceMonths(ParseCount(parts));
            Console.WriteLine($"-> {clock.Today:yyyy-MM-dd}");
            break;

        case "run":
            await RunGenerationAsync(provider, clock.Today);
            break;

        case "auto":
            // Advance month-by-month for N steps, generating each step.
            var steps = ParseCount(parts);
            for (var i = 0; i < steps; i++)
            {
                await RunGenerationAsync(provider, clock.Today);
                clock.AdvanceMonths(1);
            }
            break;

        case "help":
            PrintHelp();
            break;

        case "quit":
        case "exit":
            return 0;

        default:
            Console.WriteLine($"Unknown command '{cmd}'. Type 'help'.");
            break;
    }
}

return 0;

static async Task RunGenerationAsync(IServiceProvider provider, DateOnly asOf)
{
    using var scope = provider.CreateScope();
    var useCase = scope.ServiceProvider.GetRequiredService<GenerateMonthlyTuitionUseCase>();
    try
    {
        var result = await useCase.ExecuteAsync(asOf);
        Console.WriteLine($"[{asOf:yyyy-MM-dd}] month {result.Month}: {result.Created} created, {result.Skipped} skipped.");
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"Generation failed: {ex.Message}");
    }
}

static int ParseCount(string[] parts) =>
    parts.Length > 1 && int.TryParse(parts[1], out var n) && n > 0 ? n : 1;

static void PrintHelp()
{
    Console.WriteLine("""
        Commands:
          now            show the current virtual date
          +1d [N]        advance the virtual clock by N days (default 1)
          +1m [N]        advance the virtual clock by N months (default 1)
          run            generate this month's tuition for active enrollments
          auto [N]       run + advance one month, repeated N times (default 1)
          help           show this help
          quit           exit
        """);
}

static string? FindAppRoot()
{
    foreach (var start in new[] { AppContext.BaseDirectory, Directory.GetCurrentDirectory() })
    {
        var dir = new DirectoryInfo(start);
        while (dir is not null)
        {
            if (File.Exists(Path.Combine(dir.FullName, "appsettings.json"))
                && File.Exists(Path.Combine(dir.FullName, "SRJBackend.csproj")))
                return dir.FullName;
            dir = dir.Parent;
        }
    }
    return null;
}
