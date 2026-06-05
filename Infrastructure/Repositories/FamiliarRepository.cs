using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class FamiliarRepository : IFamiliarRepository
{
    private readonly SRJDbContext _context;

    public FamiliarRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> ExistsByPersonIdAsync(int personId)
    {
        return await _context.Familiars
            .AnyAsync(f => f.PersonId == personId);
    }

    public async Task CreateAsync(DFamiliar familiar, int personId)
    {
        var f = new Familiar
        {
            PersonId = personId,
            LevelOfEducationId = familiar.LevelOfEducationId,
            Occupation = familiar.Occupation,
            Workplace = familiar.WorkCenter,
            Lives = familiar.Lives
        };
        _context.Familiars.Add(f);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(DFamiliar familiar, int personId)
    {
        var f = await _context.Familiars.FindAsync(personId);
        if (f == null) return;
        f.LevelOfEducationId = familiar.LevelOfEducationId;
        f.Occupation = familiar.Occupation;
        f.Workplace = familiar.WorkCenter;
        f.Lives = familiar.Lives;
        await _context.SaveChangesAsync();
    }

    public async Task CreateRelationshipAsync(DFamiliar familiar, int familiarId, int studentId)
    {
        var relationship = new FamiliarStudentRelationship
        {
            FamiliarId = familiarId,
            StudentId = studentId,
            LivesTogether = familiar.LivesWithStudent,
            FamiliarRelationshipTypeId = familiar.RelationshipId,
            Isguardian = familiar.IsGuardian
        };
        _context.FamiliarStudentRelationships.Add(relationship);
        await _context.SaveChangesAsync();
    }

    public async Task<bool> TryDeleteAsync(int personId)
    {
        var familiar = await _context.Familiars.FindAsync(personId);
        if (familiar == null) return false;
        try
        {
            _context.Familiars.Remove(familiar);
            await _context.SaveChangesAsync();
            return true;
        }
        catch (DbUpdateException)
        {
            _context.Entry(familiar).State = EntityState.Unchanged;
            return false;
        }
    }
}
