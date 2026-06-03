using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Queries;
using SRJBackend.Infrastructure.Repositories;

namespace SRJBackend.Infrastructure.Extensions;

public static class AcademicServiceExtensions
{
    public static IServiceCollection AddAcademicServices(this IServiceCollection services)
    {
        services.AddScoped<IInstitutionRepository, InstitutionRepository>();
        services.AddScoped<IInstitutionQueries, InstitutionQueries>();
        services.AddScoped<CreateInstitutionUseCase>();
        services.AddScoped<UpdateInstitutionUseCase>();
        services.AddScoped<DeleteInstitutionUseCase>();

        services.AddScoped<ISchoolYearRepository, SchoolYearRepository>();
        services.AddScoped<ISchoolYearQueries, SchoolYearQueries>();
        services.AddScoped<CreateSchoolYearUseCase>();
        services.AddScoped<UpdateSchoolYearUseCase>();
        services.AddScoped<DeleteSchoolYearUseCase>();

        services.AddScoped<IGradeRepository, GradeRepository>();
        services.AddScoped<IGradeQueries, GradeQueries>();
        services.AddScoped<CreateGradeUseCase>();
        services.AddScoped<UpdateGradeUseCase>();
        services.AddScoped<DeleteGradeUseCase>();

        services.AddScoped<ILevelRepository, LevelRepository>();
        services.AddScoped<ILevelQueries, LevelQueries>();
        services.AddScoped<CreateLevelUseCase>();
        services.AddScoped<UpdateLevelUseCase>();
        services.AddScoped<DeleteLevelUseCase>();

        services.AddScoped<IGradeOfferingRepository, GradeOfferingRepository>();
        services.AddScoped<IGradeOfferingQueries, GradeOfferingQueries>();
        services.AddScoped<CreateGradeOfferingUseCase>();
        services.AddScoped<UpdateGradeOfferingUseCase>();
        services.AddScoped<DeleteGradeOfferingUseCase>();

        return services;
    }
}
