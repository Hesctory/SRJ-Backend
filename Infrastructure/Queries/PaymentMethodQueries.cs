using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class PaymentMethodQueries : IPaymentMethodQueries
{
    private readonly SRJDbContext _context;

    public PaymentMethodQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<PaymentMethodDTO>> GetAllAsync()
    {
        return await _context.PaymentMethods
            .AsNoTracking()
            .OrderBy(m => m.Id)
            .Select(m => new PaymentMethodDTO(m.Id, m.Name))
            .ToListAsync();
    }
}
