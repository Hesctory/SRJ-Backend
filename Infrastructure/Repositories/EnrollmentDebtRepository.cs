using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Constants;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class EnrollmentDebtRepository : IEnrollmentDebtRepository
{
    private readonly SRJDbContext _context;

    public EnrollmentDebtRepository(SRJDbContext context)
    {
        _context = context;
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
}
