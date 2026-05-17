using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class SchoolFeeConceptRepository : ISchoolFeeConceptRepository
{
    private readonly SRJDbContext _context;

    public SchoolFeeConceptRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> NameExistsAsync(string name, int? excludeId = null)
    {
        return await _context.SchoolFeeConcepts
            .AnyAsync(s => s.Name == name && (excludeId == null || s.Id != excludeId));
    }

    public async Task<int> CreateAsync(CreateSchoolFeeConceptDTO dto)
    {
        var concept = new SchoolFeeConcept { Name = dto.Name };
        _context.SchoolFeeConcepts.Add(concept);
        await _context.SaveChangesAsync();
        return concept.Id;
    }

    public async Task UpdateAsync(int id, CreateSchoolFeeConceptDTO dto)
    {
        var concept = await _context.SchoolFeeConcepts.FindAsync(id);
        concept!.Name = dto.Name;
        await _context.SaveChangesAsync();
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var concept = await _context.SchoolFeeConcepts.FindAsync(id);
        if (concept == null) return false;
        _context.SchoolFeeConcepts.Remove(concept);
        await _context.SaveChangesAsync();
        return true;
    }
}
