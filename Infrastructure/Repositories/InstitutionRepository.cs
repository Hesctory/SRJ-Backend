using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class InstitutionRepository : IInstitutionRepository
{
    private readonly SRJDbContext _context;

    public InstitutionRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<bool> ExistsAsync(int id)
    {
        return await _context.Institutions.AnyAsync(i => i.Id == id);
    }

    public async Task<bool> RucExistsAsync(string ruc, int? excludeId = null)
    {
        return await _context.Institutions
            .AnyAsync(i => i.Ruc == ruc && (excludeId == null || i.Id != excludeId));
    }

    public async Task<int> CreateAsync(CreateInstitutionDTO dto)
    {
        var institution = new Institution
        {
            Name = dto.Name,
            Ruc = dto.Ruc,
            RucStateId = dto.RucStateId
        };
        _context.Institutions.Add(institution);
        await _context.SaveChangesAsync();
        return institution.Id;
    }

    public async Task UpdateAsync(int id, CreateInstitutionDTO dto)
    {
        var institution = await _context.Institutions.FindAsync(id);
        institution!.Name = dto.Name;
        institution.Ruc = dto.Ruc;
        institution.RucStateId = dto.RucStateId;
        await _context.SaveChangesAsync();
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var institution = await _context.Institutions.FindAsync(id);
        if (institution == null) return false;
        _context.Institutions.Remove(institution);
        await _context.SaveChangesAsync();
        return true;
    }
}
