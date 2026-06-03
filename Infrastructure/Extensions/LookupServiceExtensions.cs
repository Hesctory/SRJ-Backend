using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Queries;

namespace SRJBackend.Infrastructure.Extensions;

public static class LookupServiceExtensions
{
    public static IServiceCollection AddLookupServices(this IServiceCollection services)
    {
        services.AddScoped<ILookupQueries, LookupQueries>();
        services.AddScoped<ILocationQueries, LocationQueries>();
        services.AddScoped<IShiftQueries, ShiftQueries>();
        services.AddScoped<ISectionQueries, SectionQueries>();
        return services;
    }
}
