using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class DebtInstallmentQueries : IDebtInstallmentQueries
{
    private readonly SRJDbContext _context;

    public DebtInstallmentQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<DebtInstallmentDTO> Items, int Total)> GetByDebtAsync(
        long debtId, int skip, int take)
    {
        var query = _context.PaymentDebtAllocations
            .AsNoTracking()
            .Where(a => a.DebtId == debtId)
            .Join(_context.Payments, a => a.PaymentId, p => p.Id,
                (a, p) => new { Alloc = a, Payment = p })
            .Join(_context.PaymentMethods, ap => ap.Payment.PaymentMethodId, pm => pm.Id,
                (ap, pm) => new { ap.Alloc, ap.Payment, Method = pm });

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(x => x.Payment.PaymentDate)
            .Skip(skip)
            .Take(take)
            .Select(x => new DebtInstallmentDTO(
                x.Alloc.Id,
                x.Alloc.DebtId,
                x.Alloc.AmountApplied,
                x.Payment.PaymentDate,
                x.Method.Name,
                x.Payment.NOperation))
            .ToListAsync();

        return (items, total);
    }

    public async Task<DebtInstallmentDTO?> GetByIdAsync(long id)
    {
        return await _context.PaymentDebtAllocations
            .AsNoTracking()
            .Where(a => a.Id == id)
            .Join(_context.Payments, a => a.PaymentId, p => p.Id,
                (a, p) => new { Alloc = a, Payment = p })
            .Join(_context.PaymentMethods, ap => ap.Payment.PaymentMethodId, pm => pm.Id,
                (ap, pm) => new { ap.Alloc, ap.Payment, Method = pm })
            .Select(x => new DebtInstallmentDTO(
                x.Alloc.Id,
                x.Alloc.DebtId,
                x.Alloc.AmountApplied,
                x.Payment.PaymentDate,
                x.Method.Name,
                x.Payment.NOperation))
            .FirstOrDefaultAsync();
    }
}
