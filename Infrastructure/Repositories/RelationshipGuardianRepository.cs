using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class RelationshipGuardianRepository : IRelationshipGuardianRepository
{
    private readonly SRJDbContext _context;

    public RelationshipGuardianRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<RelationshipGuardianDTO>> GetAllAsync()
    {
        return await _context.RelationshipGuardians
            .Select(r => new RelationshipGuardianDTO { id = r.Id, Name = r.Name })
            .ToListAsync();
    }
}
