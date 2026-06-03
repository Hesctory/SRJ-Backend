using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Queries;
using SRJBackend.Infrastructure.Repositories;

namespace SRJBackend.Infrastructure.Extensions;

public static class AccountingServiceExtensions
{
    public static IServiceCollection AddAccountingServices(this IServiceCollection services)
    {
        services.AddScoped<IAccountRepository, AccountRepository>();
        services.AddScoped<IAccountQueries, AccountQueries>();
        services.AddScoped<CreateAccountUseCase>();
        services.AddScoped<UpdateAccountUseCase>();
        services.AddScoped<DeleteAccountUseCase>();
        return services;
    }
}
