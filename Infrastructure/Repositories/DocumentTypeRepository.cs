using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class DocumentTypeRepository : IDocumentTypeRepository
{
    private readonly SRJDbContext _context;

    public DocumentTypeRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<DocumentTypeDTO>> GetAllAsync()
    {
        return await _context.DocumentTypes
            .Select(d => new DocumentTypeDTO { id = d.Id, Name = d.Name })
            .ToListAsync();
    }
}
