using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class FamiliarStudentRelationshipRepository : IFamiliarStudentRelationshipRepository
{
    private readonly SRJDbContext _context;

    public FamiliarStudentRelationshipRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> ExistsByStudentIdAsync(int studentId) =>
        await _context.FamiliarStudentRelationships.AnyAsync(r => r.StudentId == studentId);

    public async Task<List<int>> GetFamiliarIdsByStudentIdAsync(int studentId) =>
        await _context.FamiliarStudentRelationships
            .Where(r => r.StudentId == studentId)
            .Select(r => r.FamiliarId)
            .ToListAsync();

    public async Task DeleteByStudentIdAsync(int studentId)
    {
        var relationships = await _context.FamiliarStudentRelationships
            .Where(r => r.StudentId == studentId)
            .ToListAsync();

        _context.FamiliarStudentRelationships.RemoveRange(relationships);
        await _context.SaveChangesAsync();
    }
}
