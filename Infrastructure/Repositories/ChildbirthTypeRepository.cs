using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class ChildbirthTypeRepository : IChildbirthTypeRepository
{
    private readonly SRJDbContext _context;

    public ChildbirthTypeRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<ChildbirthTypeDTO>> GetAllAsync()
    {
        return await _context.ChildbirthTypes
            .Select(c => new ChildbirthTypeDTO { id = c.Id, Name = c.Name! })
            .ToListAsync();
    }
}
