using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Services;

/// <summary>
/// Daily idempotent tick that generates the current month's tuition debts for all active
/// enrollments. Each run is a no-op once that month's debts exist, so it is safe to run on
/// every loop and self-heals after downtime. Configured via the "TuitionScheduler" section.
/// </summary>
public class TuitionSchedulerHostedService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IClock _clock;
    private readonly IConfiguration _config;
    private readonly ILogger<TuitionSchedulerHostedService> _logger;

    public TuitionSchedulerHostedService(
        IServiceScopeFactory scopeFactory,
        IClock clock,
        IConfiguration config,
        ILogger<TuitionSchedulerHostedService> logger)
    {
        _scopeFactory = scopeFactory;
        _clock = clock;
        _config = config;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_config.GetValue("TuitionScheduler:Enabled", true))
        {
            _logger.LogInformation("Tuition scheduler disabled by configuration.");
            return;
        }

        var intervalHours = _config.GetValue("TuitionScheduler:IntervalHours", 24.0);
        var interval = TimeSpan.FromHours(intervalHours <= 0 ? 24.0 : intervalHours);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var useCase = scope.ServiceProvider.GetRequiredService<GenerateMonthlyTuitionUseCase>();
                var result = await useCase.ExecuteAsync(_clock.Today);
                _logger.LogInformation(
                    "Tuition generation tick ({Date}): month {Month}, {Created} created, {Skipped} skipped.",
                    _clock.Today, result.Month, result.Created, result.Skipped);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Tuition generation tick failed.");
            }

            try
            {
                await Task.Delay(interval, stoppingToken);
            }
            catch (TaskCanceledException)
            {
                break;
            }
        }
    }
}
