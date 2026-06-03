using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IPaymentMethodQueries
{
    Task<List<PaymentMethodDTO>> GetAllAsync();
}
