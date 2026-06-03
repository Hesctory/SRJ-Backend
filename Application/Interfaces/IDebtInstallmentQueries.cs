using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IDebtInstallmentQueries
{
    Task<(List<DebtInstallmentDTO> Items, int Total)> GetByDebtAsync(long debtId, int skip, int take);
    Task<DebtInstallmentDTO?> GetByIdAsync(long id);
}
