using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class LanguageRepository : ILanguageRepository
{
    private readonly SRJDbContext _context;

    public LanguageRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<LanguageDTO>> GetAllAsync()
    {
        return await _context.Languages
            .Select(l => new LanguageDTO { id = l.Id, Name = l.Name! })
            .ToListAsync();
    }
}
