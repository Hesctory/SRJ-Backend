using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class CivilStateRepository : ICivilStateRepository
{
    private readonly SRJDbContext _context;

    public CivilStateRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<CivilStateDTO>> GetAllAsync()
    {
        return await _context.CivilStates
            .Select(c => new CivilStateDTO { id = c.Id, Name = c.Name })
            .ToListAsync();
    }
}
