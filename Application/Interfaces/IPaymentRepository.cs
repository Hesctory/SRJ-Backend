using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IPaymentRepository
{
    Task<int> CreateAsync(DPayment payment);
}
