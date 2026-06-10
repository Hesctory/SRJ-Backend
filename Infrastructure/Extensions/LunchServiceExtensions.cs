using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Queries;
using SRJBackend.Infrastructure.Repositories;

namespace SRJBackend.Infrastructure.Extensions;

public static class LunchServiceExtensions
{
    public static IServiceCollection AddLunchServices(this IServiceCollection services)
    {
        services.AddScoped<ILunchCategoryRepository, LunchCategoryRepository>();
        services.AddScoped<ILunchCategoryQueries, LunchCategoryQueries>();
        services.AddScoped<CreateLunchCategoryUseCase>();
        services.AddScoped<UpdateLunchCategoryUseCase>();
        services.AddScoped<DeleteLunchCategoryUseCase>();

        services.AddScoped<ILunchRepository, LunchRepository>();
        services.AddScoped<ILunchQueries, LunchQueries>();
        services.AddScoped<CreateLunchUseCase>();
        services.AddScoped<UpdateLunchUseCase>();
        services.AddScoped<DeleteLunchUseCase>();

        return services;
    }
}
