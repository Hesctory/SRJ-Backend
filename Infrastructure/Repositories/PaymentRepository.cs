using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Constants;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class PaymentRepository : IPaymentRepository
{
    private readonly SRJDbContext _context;

    public PaymentRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<int> CreateAsync(DPayment payment)
    {
        var efPayment = new Payment
        {
            PaymentDate = payment.Date,
            Amount = payment.Amount,
            PaymentMethodId = payment.PaymentMethodId,
            NOperation = payment.NOperation,
            IsVoided = false,
            CreatedAt = DateTime.UtcNow
        };
        _context.Payments.Add(efPayment);
        await _context.SaveChangesAsync();

        foreach (var line in payment.Lines)
        {
            _context.PaymentDebtAllocations.Add(new PaymentDebtAllocation
            {
                PaymentId = efPayment.Id,
                DebtId = line.DebtId,
                AmountApplied = line.Allocated,
                AllocatedAt = DateTime.UtcNow
            });
        }

        await _context.SaveChangesAsync();

        var statusIds = await _context.DebtStatuses
            .ToDictionaryAsync(s => s.Code, s => s.Id);

        foreach (var line in payment.Lines)
        {
            var debt = await _context.EnrollmentDebts.FindAsync(line.DebtId)
                ?? throw new KeyNotFoundException($"Deuda {line.DebtId} no encontrada.");

            var targetCode = DebtStatusCodes.FromEnum(line.NewStatus);
            if (!statusIds.TryGetValue(targetCode, out var statusId))
                throw new InvalidOperationException($"Estado '{targetCode}' no encontrado en la base de datos.");

            debt.StatusId = statusId;
            debt.UpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();
        return efPayment.Id;
    }
}
