using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class LevelOfEducationRepository : ILevelOfEducationRepository
{
    private readonly SRJDbContext _context;

    public LevelOfEducationRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<LevelOfEducationDTO>> GetAllAsync()
    {
        return await _context.LevelOfEducations
            .Select(l => new LevelOfEducationDTO { id = l.Id, Name = l.Name })
            .ToListAsync();
    }
}
