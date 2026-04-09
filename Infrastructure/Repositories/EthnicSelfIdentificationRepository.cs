using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class EthnicSelfIdentificationRepository : IEthnicSelfIdentificationRepository
{
    private readonly SRJDbContext _context;

    public EthnicSelfIdentificationRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<List<EthnicSelfIdentificationDTO>> GetAllAsync()
    {
        return await _context.EthnicSelfIdentifications
            .Select(e => new EthnicSelfIdentificationDTO { id = e.Id, Name = e.EthnicSelfIdentification1 })
            .ToListAsync();
    }
}
