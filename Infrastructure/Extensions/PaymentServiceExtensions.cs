using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure.Queries;
using SRJBackend.Infrastructure.Repositories;
using SRJBackend.Infrastructure.Services;

namespace SRJBackend.Infrastructure.Extensions;

public static class PaymentServiceExtensions
{
    public static IServiceCollection AddPaymentServices(this IServiceCollection services)
    {
        services.AddMemoryCache();
        services.AddSingleton<IPaymentPreviewCache, MemoryPaymentPreviewCache>();
        services.AddScoped<IEnrollmentDebtRepository, EnrollmentDebtRepository>();
        services.AddScoped<IEnrollmentDebtQueries, EnrollmentDebtQueries>();
        services.AddScoped<IDebtInstallmentQueries, DebtInstallmentQueries>();
        services.AddScoped<IPaymentMethodQueries, PaymentMethodQueries>();
        services.AddScoped<IPaymentRepository, PaymentRepository>();
        services.AddScoped<CreatePaymentPreviewUseCase>();
        services.AddScoped<ConfirmPaymentUseCase>();
        return services;
    }
}
