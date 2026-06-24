using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Constants;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class EnrollmentDebtRepository : IEnrollmentDebtRepository
{
    private readonly SRJDbContext _context;
    private readonly IClock _clock;

    public EnrollmentDebtRepository(SRJDbContext context, IClock clock)
    {
        _context = context;
        _clock = clock;
    }

    public async Task<List<DDebt>> GetPayableDebtsAsync(int enrollmentId, long? debtId)
    {
        var payableStatuses = new[]
        {
            DebtStatusCodes.Pending,
            DebtStatusCodes.PartiallyPaid,
            DebtStatusCodes.Overdue
        };

        var query = _context.VStudentBalances
            .AsNoTracking()
            .Where(d => d.EnrollmentId == enrollmentId
                     && payableStatuses.Contains(d.StatusCode)
                     && d.BalanceDue > 0);

        if (debtId.HasValue)
            query = query.Where(d => d.DebtId == debtId.Value);

        var rows = await query.OrderBy(d => d.DueDate).ToListAsync();

        return rows.Select(d => DDebt.Reconstitute(
            d.DebtId!.Value,
            d.EnrollmentId!.Value,
            d.Description ?? "",
            d.BalanceDue ?? 0m,
            DebtStatusCodes.ToEnum(d.StatusCode!),
            d.DueDate!.Value))
            .ToList();
    }

    public async Task AddRangeAsync(IEnumerable<DDebt> debts, int? createdBy)
    {
        var list = debts.ToList();
        if (list.Count == 0) return;

        var chargeTypeIds = await _context.ChargeTypes
            .ToDictionaryAsync(c => c.Code, c => c.Id);
        var statusIds = await _context.DebtStatuses
            .ToDictionaryAsync(s => s.Code, s => s.Id);

        var now = _clock.UtcNow;

        foreach (var debt in list)
        {
            _context.EnrollmentDebts.Add(new EnrollmentDebt
            {
                StudentId = debt.StudentId,
                EnrollmentId = debt.EnrollmentId,
                SchoolYearId = debt.SchoolYearId,
                ChargeTypeId = chargeTypeIds[debt.ChargeTypeCode],
                Amount = debt.Amount,
                Description = debt.Description,
                DueDate = debt.DueDate,
                PeriodMonth = debt.PeriodMonth,
                StatusId = statusIds[DebtStatusCodes.FromEnum(debt.Status)],
                CreatedAt = now,
                UpdatedAt = now,
                CreatedBy = createdBy,
            });
        }

        await _context.SaveChangesAsync();
    }

    public async Task<bool> ChargeExistsAsync(int enrollmentId, string chargeTypeCode, short? periodMonth)
    {
        return await _context.EnrollmentDebts.AnyAsync(d =>
            d.EnrollmentId == enrollmentId
            && d.ChargeType.Code == chargeTypeCode
            && d.PeriodMonth == periodMonth);
    }
}
