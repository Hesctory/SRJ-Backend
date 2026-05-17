using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class LookupQueries : ILookupQueries
{
    private readonly SRJDbContext _context;

    public LookupQueries(SRJDbContext context)
    {
        _context = context;
    }

    public Task<List<GenderDTO>> GetGendersAsync() =>
        _context.Genders.AsNoTracking()
            .Select(g => new GenderDTO { id = g.Id, Name = g.Name })
            .ToListAsync();

    public Task<List<DocumentTypeDTO>> GetDocumentTypesAsync() =>
        _context.DocumentTypes.AsNoTracking()
            .Select(d => new DocumentTypeDTO { id = d.Id, Name = d.Name })
            .ToListAsync();

    public Task<List<ReligionDTO>> GetReligionsAsync() =>
        _context.Religions.AsNoTracking()
            .Select(r => new ReligionDTO { id = r.Id, Name = r.Name })
            .ToListAsync();

    public Task<List<CivilStateDTO>> GetCivilStatesAsync() =>
        _context.CivilStates.AsNoTracking()
            .Select(c => new CivilStateDTO { id = c.Id, Name = c.Name })
            .ToListAsync();

    public Task<List<LanguageDTO>> GetLanguagesAsync() =>
        _context.Languages.AsNoTracking()
            .Select(l => new LanguageDTO { id = l.Id, Name = l.Name! })
            .ToListAsync();

    public Task<List<EthnicSelfIdentificationDTO>> GetEthnicSelfIdentificationsAsync() =>
        _context.EthnicSelfIdentifications.AsNoTracking()
            .Select(e => new EthnicSelfIdentificationDTO { id = e.Id, Name = e.EthnicSelfIdentification1 })
            .ToListAsync();

    public Task<List<ChildbirthTypeDTO>> GetChildbirthTypesAsync() =>
        _context.ChildbirthTypes.AsNoTracking()
            .Select(c => new ChildbirthTypeDTO { id = c.Id, Name = c.Name! })
            .ToListAsync();

    public Task<List<FamiliarRelationshipTypeDTO>> GetFamiliarRelationshipTypesAsync() =>
        _context.FamiliarRelationshipTypes.AsNoTracking()
            .Select(r => new FamiliarRelationshipTypeDTO { id = r.Id, Name = r.Name })
            .ToListAsync();

    public Task<List<DisabilityTypeDTO>> GetDisabilityTypesAsync() =>
        _context.DisabilityTypes.AsNoTracking()
            .Select(d => new DisabilityTypeDTO { id = d.Id, Type = d.Type })
            .ToListAsync();

    public Task<List<DisabilityDegreeDTO>> GetDisabilityDegreesAsync() =>
        _context.DisabilityDegrees.AsNoTracking()
            .Select(d => new DisabilityDegreeDTO { id = d.Id, Degree = d.Degree })
            .ToListAsync();

    public Task<List<LevelOfEducationDTO>> GetLevelOfEducationsAsync() =>
        _context.LevelOfEducations.AsNoTracking()
            .Select(l => new LevelOfEducationDTO { id = l.Id, Name = l.Name })
            .ToListAsync();

    public Task<List<RucStateDTO>> GetRucStatesAsync() =>
        _context.RucStates.AsNoTracking()
            .Select(r => new RucStateDTO { id = r.Id, Name = r.Name })
            .ToListAsync();
}
