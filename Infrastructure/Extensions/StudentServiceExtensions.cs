using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Queries;
using SRJBackend.Infrastructure.Repositories;

namespace SRJBackend.Infrastructure.Extensions;

public static class StudentServiceExtensions
{
    public static IServiceCollection AddStudentServices(this IServiceCollection services)
    {
        services.AddScoped<IPersonRepository, PersonRepository>();
        services.AddScoped<IStudentRepository, StudentRepository>();
        services.AddScoped<IStudentHomeRepository, StudentHomeRepository>();
        services.AddScoped<IFamiliarRepository, FamiliarRepository>();
        services.AddScoped<IFamiliarStudentRelationshipRepository, FamiliarStudentRelationshipRepository>();
        services.AddScoped<IStudentQueries, StudentQueries>();
        services.AddScoped<CreateStudentUseCase>();
        services.AddScoped<UpdateStudentUseCase>();
        services.AddScoped<DeleteStudentUseCase>();
        return services;
    }
}
