using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class ReligionRepository : IReligionRepository
{
    private readonly SRJDbContext _context;

    public ReligionRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<ReligionDTO>> GetAllAsync()
    {
        return await _context.Religions
            .Select(r => new ReligionDTO { id = r.Id, Name = r.Name })
            .ToListAsync();
    }
}
