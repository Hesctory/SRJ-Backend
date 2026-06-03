using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class EnrollmentDebtQueries : IEnrollmentDebtQueries
{
    private readonly SRJDbContext _context;

    public EnrollmentDebtQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<EnrollmentDebtDTO> Items, int Total)> GetByEnrollmentAsync(
        int enrollmentId, int skip, int take)
    {
        var query = _context.VStudentBalances
            .AsNoTracking()
            .Where(d => d.EnrollmentId == enrollmentId);

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(d => d.DueDate)
            .Skip(skip)
            .Take(take)
            .Select(d => new EnrollmentDebtDTO(
                d.DebtId!.Value,
                d.EnrollmentId!.Value,
                d.Description,
                d.AmountCharged ?? 0m,
                d.TotalPaid ?? 0m,
                d.DueDate!.Value,
                d.StatusCode ?? "pending"))
            .ToListAsync();

        return (items, total);
    }

    public async Task<EnrollmentDebtDTO?> GetByIdAsync(long id)
    {
        return await _context.VStudentBalances
            .AsNoTracking()
            .Where(d => d.DebtId == id)
            .Select(d => new EnrollmentDebtDTO(
                d.DebtId!.Value,
                d.EnrollmentId!.Value,
                d.Description,
                d.AmountCharged ?? 0m,
                d.TotalPaid ?? 0m,
                d.DueDate!.Value,
                d.StatusCode ?? "pending"))
            .FirstOrDefaultAsync();
    }
}
