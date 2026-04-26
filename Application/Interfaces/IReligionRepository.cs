using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface IReligionRepository
{
    Task<List<ReligionDTO>> GetAllAsync();
}
