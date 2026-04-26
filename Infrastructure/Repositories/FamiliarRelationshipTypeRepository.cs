using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class FamiliarRelationshipTypeRepository : IFamiliarRelationshipTypeRepository
{
    private readonly SRJDbContext _context;

    public FamiliarRelationshipTypeRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<FamiliarRelationshipTypeDTO>> GetAllAsync()
    {
        return await _context.FamiliarRelationshipTypes
            .Select(r => new FamiliarRelationshipTypeDTO { id = r.Id, Name = r.Name })
            .ToListAsync();
    }
}
