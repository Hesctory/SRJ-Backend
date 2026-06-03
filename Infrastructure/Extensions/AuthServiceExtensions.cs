using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Repositories;
using SRJBackend.Infrastructure.Services;

namespace SRJBackend.Infrastructure.Extensions;

public static class AuthServiceExtensions
{
    public static IServiceCollection AddAuthServices(this IServiceCollection services)
    {
        services.AddScoped<IAuthRepository, AuthRepository>();
        services.AddScoped<IJwtService, JwtService>();
        services.AddScoped<LoginUseCase>();
        return services;
    }
}
