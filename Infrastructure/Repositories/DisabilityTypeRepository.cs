using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class DisabilityTypeRepository : IDisabilityTypeRepository
{
    private readonly SRJDbContext _context;

    public DisabilityTypeRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<DisabilityTypeDTO>> GetAllAsync()
    {
        return await _context.DisabilityTypes
            .Select(d => new DisabilityTypeDTO { id = d.Id, Type = d.Type })
            .ToListAsync();
    }
}
