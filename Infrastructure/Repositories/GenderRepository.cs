using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class GenderRepository : IGenderRepository
{
    private readonly SRJDbContext _context;

    public GenderRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<GenderDTO>> GetAllAsync()
    {
        return await _context.Genders
            .Select(g => new GenderDTO { id = g.Id, Name = g.Name })
            .ToListAsync();
    }
}
