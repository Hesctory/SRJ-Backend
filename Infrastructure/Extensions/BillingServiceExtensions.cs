using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Queries;
using SRJBackend.Infrastructure.Services;

namespace SRJBackend.Infrastructure.Extensions;

public static class BillingServiceExtensions
{
    public static IServiceCollection AddBillingServices(this IServiceCollection services)
    {
        services.AddSingleton<IClock, SystemClock>();
        services.AddScoped<IBillingDataQueries, BillingDataQueries>();
        services.AddScoped<GenerateEnrollmentChargesUseCase>();
        services.AddScoped<GenerateMonthlyTuitionUseCase>();
        services.AddHostedService<TuitionSchedulerHostedService>();
        return services;
    }
}
