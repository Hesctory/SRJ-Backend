using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Interfaces;

public interface IEnrollmentDebtRepository
{
    Task<List<DDebt>> GetPayableDebtsAsync(int enrollmentId, long? debtId);

    /// <summary>Persists newly-created debts, resolving charge-type/status codes to ids.</summary>
    Task AddRangeAsync(IEnumerable<DDebt> debts, int? createdBy);

    /// <summary>
    /// True if a debt already exists for this enrollment + charge type (+ month for tuition).
    /// Used to keep generation idempotent and safe to coexist with the backfill SQL.
    /// </summary>
    Task<bool> ChargeExistsAsync(int enrollmentId, string chargeTypeCode, short? periodMonth);
}
