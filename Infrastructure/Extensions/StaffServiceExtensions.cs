using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Queries;
using SRJBackend.Infrastructure.Repositories;

namespace SRJBackend.Infrastructure.Extensions;

public static class StaffServiceExtensions
{
    public static IServiceCollection AddStaffServices(this IServiceCollection services)
    {
        services.AddScoped<IWorkAreaRepository, WorkAreaRepository>();
        services.AddScoped<IWorkAreaQueries, WorkAreaQueries>();
        services.AddScoped<CreateWorkAreaUseCase>();
        services.AddScoped<UpdateWorkAreaUseCase>();
        services.AddScoped<DeleteWorkAreaUseCase>();

        services.AddScoped<IJobPositionRepository, JobPositionRepository>();
        services.AddScoped<IJobPositionQueries, JobPositionQueries>();
        services.AddScoped<CreateJobPositionUseCase>();
        services.AddScoped<UpdateJobPositionUseCase>();
        services.AddScoped<DeleteJobPositionUseCase>();

        services.AddScoped<IStaffMemberRepository, StaffMemberRepository>();
        services.AddScoped<IStaffMemberQueries, StaffMemberQueries>();
        services.AddScoped<IEmploymentContractRepository, EmploymentContractRepository>();
        services.AddScoped<IEmploymentContractQueries, EmploymentContractQueries>();
        services.AddScoped<CreateStaffMemberUseCase>();
        services.AddScoped<UpdateStaffMemberUseCase>();
        services.AddScoped<DeleteStaffMemberUseCase>();
        services.AddScoped<CreateEmploymentContractUseCase>();
        services.AddScoped<UpdateEmploymentContractUseCase>();
        services.AddScoped<DeleteEmploymentContractUseCase>();

        return services;
    }
}
