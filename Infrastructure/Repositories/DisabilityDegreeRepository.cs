using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class DisabilityDegreeRepository : IDisabilityDegreeRepository
{
    private readonly SRJDbContext _context;

    public DisabilityDegreeRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<DisabilityDegreeDTO>> GetAllAsync()
    {
        return await _context.DisabilityDegrees
            .Select(d => new DisabilityDegreeDTO { id = d.Id, Degree = d.Degree })
            .ToListAsync();
    }
}
