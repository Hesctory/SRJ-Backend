using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IEnrollmentDebtRepository
{
    Task<List<DDebt>> GetPayableDebtsAsync(int enrollmentId, long? debtId);
}
