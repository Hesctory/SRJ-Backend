using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Queries;
using SRJBackend.Infrastructure.Repositories;

namespace SRJBackend.Infrastructure.Extensions;

public static class SchoolFeeServiceExtensions
{
    public static IServiceCollection AddSchoolFeeServices(this IServiceCollection services)
    {
        services.AddScoped<ISchoolFeeConceptRepository, SchoolFeeConceptRepository>();
        services.AddScoped<ISchoolFeeConceptQueries, SchoolFeeConceptQueries>();
        services.AddScoped<CreateSchoolFeeConceptUseCase>();
        services.AddScoped<UpdateSchoolFeeConceptUseCase>();
        services.AddScoped<DeleteSchoolFeeConceptUseCase>();
        return services;
    }
}
