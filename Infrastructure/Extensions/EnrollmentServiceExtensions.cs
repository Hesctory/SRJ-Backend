using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Queries;
using SRJBackend.Infrastructure.Repositories;

namespace SRJBackend.Infrastructure.Extensions;

public static class EnrollmentServiceExtensions
{
    public static IServiceCollection AddEnrollmentServices(this IServiceCollection services)
    {
        services.AddScoped<IEnrollmentRepository, EnrollmentRepository>();
        services.AddScoped<IGradeOfferingShiftSectionRepository, GradeOfferingShiftSectionRepository>();
        services.AddScoped<IEnrollmentQueries, EnrollmentQueries>();
        services.AddScoped<IUnitOfWork, UnitOfWork>();
        services.AddScoped<CreateEnrollmentUseCase>();
        services.AddScoped<UpdateEnrollmentUseCase>();
        services.AddScoped<DeleteEnrollmentUseCase>();
        return services;
    }
}
