using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class RucStateRepository : IRucStateRepository
{
    private readonly SRJDbContext _context;

    public RucStateRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<RucStateDTO>> GetAllAsync()
    {
        return await _context.RucStates
            .Select(r => new RucStateDTO { id = r.Id, Name = r.Name })
            .ToListAsync();
    }
}
